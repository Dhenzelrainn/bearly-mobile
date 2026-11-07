import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routes/app_route_names.dart';
import '../../../core/theme/bearly_theme.dart';
import '../data/postal_code_service.dart';
import '../data/psgc_service.dart';
import '../data/registration_repository.dart';
import '../models/account_role.dart';
import '../models/registration_region_fields.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/document_source_sheet.dart';
import '../widgets/document_upload_card.dart';
import '../widgets/location_picker_sheet.dart';
import '../widgets/password_requirements.dart';
import '../widgets/phone_number_field.dart';
import '../widgets/registration_presentation.dart';
import '../widgets/role_card.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    this.initialRole = AccountRole.buyer,
    this.registrationDataSource,
    this.psgcService,
    this.postalCodeService,
  });

  final AccountRole initialRole;
  final RegistrationDataSource? registrationDataSource;
  final PsgcService? psgcService;
  final PostalCodeService? postalCodeService;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _personalKey = GlobalKey<FormState>();
  final _addressKey = GlobalKey<FormState>();
  final _finalKey = GlobalKey<FormState>();

  late final _psgc = widget.psgcService ?? const PsgcService();
  final _registrationScrollController = ScrollController();
  late final _postalCodes = widget.postalCodeService ?? PostalCodeService();
  final _imagePicker = ImagePicker();
  late final RegistrationDataSource _registration =
      widget.registrationDataSource ?? RegistrationRepository();

  late AccountRole _role;
  int _currentStep = 0;

  bool _termsAccepted = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _emailCodeSent = false;
  bool _emailVerified = false;
  bool _emailBusy = false;
  bool _submitting = false;
  bool _partnersLoading = false;

  bool _manualAddress = false;
  bool _addressLoading = true;
  String? _addressError;
  bool _postalAutoFilled = false;
  String _postalHint = 'Select municipality first';
  String? _verificationId;
  String? _emailVerificationMessage;
  String? _submissionError;
  String? _partnersError;
  int _retryAfterSeconds = 0;
  Timer? _retryTimer;
  Timer? _partnerLookupTimer;

  List<LocationOption> _regions = const [];
  List<LocationOption> _provinces = const [];
  List<LocationOption> _cities = const [];
  List<LocationOption> _barangays = const [];
  List<RegistrationPartner> _partners = const [];
  RegistrationPartner? _selectedPartner;
  LocationOption? _region;
  LocationOption? _province;
  LocationOption? _city;
  LocationOption? _barangay;

  PlatformFile? _validId;
  PlatformFile? _orCr;
  PlatformFile? _driverLicense;
  PlatformFile? _businessPermit;

  final firstName = TextEditingController();
  final middleInitial = TextEditingController();
  final lastName = TextEditingController();
  String? sex;
  final email = TextEditingController();
  final emailCode = TextEditingController();
  final contact = TextEditingController();
  String _phoneCountryCode = 'PH';
  DateTime? birthday;
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  final regionManual = TextEditingController();
  final provinceManual = TextEditingController();
  final cityManual = TextEditingController();
  final barangayManual = TextEditingController();
  final street = TextEditingController();
  final house = TextEditingController();
  final postal = TextEditingController();
  final manualRegionCode = TextEditingController();
  final manualCityCode = TextEditingController();

  final businessName = TextEditingController();
  String _riderWorkType = 'local';
  final vehicleModel = TextEditingController();
  String? vehicleType;
  final plateNumber = TextEditingController();

  static const _localVehicleTypes = ['Motorcycle', 'Tricycle', 'E-bike'];
  static const _courierVehicleTypes = ['Van'];
  bool get _isRider => _role == AccountRole.rider;
  bool get _isLogistics => _role == AccountRole.logistics;
  bool get _requiresCityCode => _isRider || _isLogistics;
  List<String> get _vehicleTypes =>
      _riderWorkType == 'courier' ? _courierVehicleTypes : _localVehicleTypes;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
    _loadRegions();
    password.addListener(_refreshPasswordGuidance);
    confirmPassword.addListener(_refreshPasswordGuidance);
  }

  @override
  void dispose() {
    password.removeListener(_refreshPasswordGuidance);
    confirmPassword.removeListener(_refreshPasswordGuidance);
    for (final controller in [
      firstName,
      middleInitial,
      lastName,
      email,
      emailCode,
      contact,
      password,
      confirmPassword,
      regionManual,
      provinceManual,
      cityManual,
      barangayManual,
      street,
      house,
      postal,
      manualRegionCode,
      manualCityCode,
      businessName,
      vehicleModel,
      plateNumber,
    ]) {
      controller.dispose();
    }
    _retryTimer?.cancel();
    _partnerLookupTimer?.cancel();
    _registrationScrollController.dispose();
    super.dispose();
  }

  void _refreshPasswordGuidance() {
    if (mounted) setState(() {});
  }

  int? get _age {
    if (birthday == null) return null;
    final now = DateTime.now();
    var years = now.year - birthday!.year;
    if (now.isBefore(DateTime(now.year, birthday!.month, birthday!.day))) {
      years--;
    }
    return years < 0 ? 0 : years;
  }

  String get _stepTitle => switch (_currentStep) {
    0 => 'Personal Information',
    1 => 'Address',
    _ =>
      _role == AccountRole.buyer
          ? 'Review & Submit'
          : _isLogistics
          ? 'Provider & Documents'
          : 'Vehicle & Documents',
  };

  Future<void> _loadRegions() async {
    setState(() {
      _addressLoading = true;
      _addressError = null;
    });
    try {
      final data = await _psgc.regions();
      if (!mounted) return;
      setState(() {
        _regions = data;
        _region = null;
        _provinces = const [];
        _cities = const [];
        _barangays = const [];
        _addressLoading = false;
        if (data.isEmpty) {
          _addressError = 'No valid PSGC regions were returned.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _addressLoading = false;
        _addressError =
            'Address service is unavailable. Retry or enter the address manually.';
      });
    }
  }

  Future<void> _loadProvinces(LocationOption region) async {
    setState(() {
      _region = region;
      _province = null;
      _city = null;
      _barangay = null;
      _provinces = const [];
      _cities = const [];
      _barangays = const [];
      postal.clear();
      _postalAutoFilled = false;
      _postalHint = 'Select municipality first';
      _addressLoading = true;
      _addressError = null;
    });

    try {
      final data = await _psgc.provincesForRegion(region.code);
      if (!mounted || _region?.code != region.code) return;
      setState(() {
        _provinces = data;
        _addressLoading = false;
        if (data.isEmpty) {
          _addressError = 'No provinces were returned for that region.';
        }
      });
    } catch (_) {
      if (!mounted || _region?.code != region.code) return;
      setState(() {
        _addressLoading = false;
        _addressError =
            'Unable to load provinces. You can enter them manually.';
      });
    }
  }

  Future<void> _loadCities(LocationOption province) async {
    setState(() {
      _province = province;
      _city = null;
      _barangay = null;
      _selectedPartner = null;
      _partners = const [];
      _cities = const [];
      _barangays = const [];
      postal.clear();
      _postalAutoFilled = false;
      _postalHint = 'Select municipality first';
      _addressLoading = true;
      _addressError = null;
    });

    try {
      final data = await _psgc.cities(province.code);
      if (!mounted) return;
      setState(() {
        _cities = data;
        _addressLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _addressLoading = false;
        _addressError = 'Unable to load cities. You can enter them manually.';
      });
    }
  }

  Future<void> _updatePostalCode(LocationOption city) async {
    final province = _province;
    if (province == null) return;

    try {
      final result = await _postalCodes.lookup(
        province: province.name,
        city: city.name,
      );
      if (!mounted || _city?.code != city.code) return;

      setState(() {
        if (result.found) {
          postal.value = TextEditingValue(
            text: result.code!,
            selection: TextSelection.collapsed(offset: result.code!.length),
          );
          _postalAutoFilled = true;
          _postalHint = 'Auto-generated from municipality';
        } else {
          postal.clear();
          _postalAutoFilled = false;
          _postalHint = result.requiresManualEntry
              ? 'Enter your postal code'
              : 'Postal code unavailable — enter manually';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        postal.clear();
        _postalAutoFilled = false;
        _postalHint = 'Postal lookup unavailable — enter manually';
      });
    }
  }

  Future<void> _loadBarangays(LocationOption city) async {
    setState(() {
      _city = city;
      _barangay = null;
      _selectedPartner = null;
      _partners = const [];
      _barangays = const [];
      postal.clear();
      _postalAutoFilled = false;
      _postalHint = 'Looking up postal code...';
      _addressLoading = true;
      _addressError = null;
    });

    await _updatePostalCode(city);
    if (_isRider) await _loadLogisticsPartners(city.code);

    try {
      final data = await _psgc.barangays(city.code);
      if (!mounted || _city?.code != city.code) return;
      setState(() {
        _barangays = data;
        _addressLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _addressLoading = false;
        _addressError =
            'Unable to load barangays. You can enter them manually.';
      });
    }
  }

  Future<void> _loadLogisticsPartners(String cityCode) async {
    if (!RegExp(r'^[0-9]{6,10}$').hasMatch(cityCode)) {
      if (mounted) {
        setState(() {
          _partners = const [];
          _selectedPartner = null;
          _partnersLoading = false;
        });
      }
      return;
    }
    setState(() {
      _partnersLoading = true;
      _partners = const [];
      _selectedPartner = null;
      _partnersError = null;
    });
    try {
      final result = await _registration.logisticsPartners(cityCode);
      if (!mounted || !_isRider || _effectiveCityCode != cityCode) return;
      setState(() {
        _partners = result;
        _partnersLoading = false;
        _partnersError = result.isEmpty
            ? 'No active Logistics partner currently serves this city.'
            : null;
      });
    } catch (error) {
      if (!mounted || !_isRider || _effectiveCityCode != cityCode) return;
      setState(() {
        _partners = const [];
        _partnersLoading = false;
        _partnersError =
            'Unable to load approved partners. Check your connection and retry.';
      });
      _showMessage(
        'Unable to load approved Logistics partners. Check your connection and retry.',
      );
    }
  }

  String get _effectiveCityCode =>
      _manualAddress ? manualCityCode.text.trim() : (_city?.code ?? '');

  void _scheduleManualPartnerLookup(String value) {
    final normalized = value.replaceAll(RegExp(r'[^0-9]'), '');
    manualCityCode.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
    _partnerLookupTimer?.cancel();
    if (!_isRider) return;
    _partnerLookupTimer = Timer(const Duration(milliseconds: 450), () {
      _loadLogisticsPartners(manualCityCode.text.trim());
    });
  }

  void _selectRole(AccountRole role) {
    setState(() {
      _role = role;
      _phoneCountryCode = 'PH';
      contact.clear();
      _termsAccepted = false;
      _selectedPartner = null;
      _partners = const [];
      if (role != AccountRole.rider) {
        _partnersLoading = false;
      }
      if (role == AccountRole.rider && vehicleType == 'Van') {
        vehicleType = null;
      }
      if (role == AccountRole.rider &&
          _riderWorkType == 'courier' &&
          vehicleType != null &&
          !_courierVehicleTypes.contains(vehicleType)) {
        vehicleType = null;
      }
    });
    if (role == AccountRole.rider && _effectiveCityCode.isNotEmpty) {
      _loadLogisticsPartners(_effectiveCityCode);
    }
  }

  Future<void> _chooseBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: birthday ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now.subtract(const Duration(days: 1)),
    );
    if (picked != null) setState(() => birthday = picked);
  }

  Future<PlatformFile?> _pickDocument() async {
    final source = await showModalBottomSheet<DocumentSource>(
      context: context,
      backgroundColor: BearlyColors.cream50,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const DocumentSourceSheet(),
    );

    if (source == null) return null;

    PlatformFile? file;

    if (source == DocumentSource.pdf) {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null) return null;
      file = result.files.single;
    } else {
      final image = await _imagePicker.pickImage(
        source: source == DocumentSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 2400,
        maxHeight: 2400,
        requestFullMetadata: false,
      );

      if (image == null) return null;

      final extension = image.name.split('.').last.toLowerCase();
      if (!const ['jpg', 'jpeg', 'png'].contains(extension)) {
        _showMessage(
          'Choose a JPG or PNG image, or upload the document as PDF.',
        );
        return null;
      }

      final bytes = await image.readAsBytes();
      file = PlatformFile(
        name: image.name,
        size: bytes.length,
        bytes: bytes,
        path: image.path,
      );
    }

    if (file.size > 5 * 1024 * 1024) {
      _showMessage('The file must not exceed 5 MB.');
      return null;
    }

    return file;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendEmailCode() async {
    final value = email.text.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      _showMessage('Enter a valid email address first.');
      return;
    }
    if (_retryAfterSeconds > 0 || _emailBusy) return;
    setState(() {
      _emailBusy = true;
      _emailVerificationMessage = null;
    });
    try {
      final challenge = await _registration.sendEmailCode(value);
      if (!mounted || email.text.trim().toLowerCase() != value.toLowerCase()) {
        return;
      }
      setState(() {
        _verificationId = challenge.verificationId;
        _emailCodeSent = true;
        _emailVerified = false;
        _emailBusy = false;
        _retryAfterSeconds = challenge.retryAfter;
        _emailVerificationMessage =
            'Code sent. It expires in about ${_durationText(challenge.expiresIn)}.';
      });
      _startRetryTimer();
    } catch (error) {
      if (!mounted || email.text.trim().toLowerCase() != value.toLowerCase()) {
        return;
      }
      setState(() {
        _emailBusy = false;
        _emailVerificationMessage = _registrationErrorMessage(error);
      });
    }
  }

  Future<void> _verifyEmailCode() async {
    final code = emailCode.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showMessage('Enter the 6-digit verification code.');
      return;
    }
    final verificationId = _verificationId;
    if (verificationId == null || !_emailCodeSent) {
      _showMessage('Request a verification code first.');
      return;
    }
    setState(() {
      _emailBusy = true;
      _emailVerificationMessage = null;
    });
    try {
      await _registration.verifyEmailCode(
        email: email.text.trim(),
        code: code,
        verificationId: verificationId,
      );
      if (!mounted || _verificationId != verificationId) return;
      setState(() {
        _emailVerified = true;
        _emailBusy = false;
        _emailVerificationMessage = 'Email address verified.';
      });
    } catch (error) {
      if (!mounted || _verificationId != verificationId) return;
      setState(() {
        _emailBusy = false;
        _emailVerified = false;
        _emailVerificationMessage = _registrationErrorMessage(error);
      });
    }
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    if (_retryAfterSeconds <= 0) return;
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _retryAfterSeconds--;
        if (_retryAfterSeconds <= 0) timer.cancel();
      });
    });
  }

  void _emailChanged() {
    _retryTimer?.cancel();
    setState(() {
      _emailCodeSent = false;
      _emailVerified = false;
      _emailBusy = false;
      _verificationId = null;
      _retryAfterSeconds = 0;
      _emailVerificationMessage = null;
      emailCode.clear();
    });
  }

  static String _durationText(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    if (minutes == 0) return '$remainder seconds';
    return '$minutes min ${remainder.toString().padLeft(2, '0')} sec';
  }

  String _registrationErrorMessage(Object error) {
    if (error is ApiHttpException) {
      final emailErrors = error.validationErrors['email'];
      if (emailErrors != null && emailErrors.isNotEmpty) {
        return '${emailErrors.first} If you already registered this email, sign in instead.';
      }
      final messages = error.validationErrors.values
          .expand((items) => items)
          .where((item) => item.trim().isNotEmpty);
      if (messages.isNotEmpty) return messages.first;
      if (error.statusCode == 429) {
        return 'Too many requests. Please wait and try again.';
      }
      if (error.statusCode >= 500) {
        return 'Bearly could not complete the request. Try again later.';
      }
    }
    if (error is ApiTransportException || error is ApiTimeoutException) {
      return 'Bearly could not confirm the request. Check your connection and retry. If you submitted an application, trying again with the same email cannot create a duplicate account.';
    }
    if (error is FormatException) return error.message;
    return 'Bearly could not complete registration. Please review your details and try again.';
  }

  bool _validatePersonal() {
    final valid = _personalKey.currentState?.validate() ?? false;
    if (!valid) return false;

    if (birthday == null) {
      _showMessage('Select your birthday.');
      return false;
    }

    if ((_role == AccountRole.buyer || _isRider) && (_age ?? 0) < 18) {
      _showMessage(
        _isRider
            ? 'Riders must be at least 18 years old.'
            : 'You must be at least 18 years old to register.',
      );
      return false;
    }

    if (!_emailVerified) {
      _showMessage('Verify this email address before continuing.');
      return false;
    }

    if (_role == AccountRole.buyer && !_termsAccepted) {
      _showMessage(
        'Accept the Terms of Service and Privacy Policy to continue.',
      );
      return false;
    }

    return true;
  }

  bool _validateAddress() {
    final valid = _addressKey.currentState?.validate() ?? false;
    if (!valid) return false;

    if (!_manualAddress && _region == null) {
      _showMessage('Select your region.');
      return false;
    }

    if (!_manualAddress &&
        (_province == null || _city == null || _barangay == null)) {
      _showMessage('Complete your province, municipality, and barangay.');
      return false;
    }

    try {
      _regionFields.toJson();
    } on ArgumentError catch (error) {
      _showMessage(error.message.toString());
      return false;
    }

    if (_requiresCityCode &&
        !RegExp(r'^[0-9]{6,10}$').hasMatch(_effectiveCityCode)) {
      _showMessage('Select a valid municipality from the address list.');
      return false;
    }

    if (_requiresCityCode &&
        !RegExp(r'^\d{10}$').hasMatch(_regionFields.regionCode ?? '')) {
      _showMessage('Select a valid 10-digit PSGC region for this application.');
      return false;
    }

    if (_isRider && _selectedPartner == null) {
      _showMessage('Select an approved Logistics partner for your city.');
      return false;
    }

    return true;
  }

  bool _validateFinalStep() {
    final valid = _finalKey.currentState?.validate() ?? false;
    if (!valid) return false;

    if (_role == AccountRole.buyer) return _termsAccepted;

    if (_isLogistics) {
      if (businessName.text.trim().isEmpty) {
        _showMessage('Enter the Logistics business name.');
        return false;
      }
      if (_validId == null) {
        _showMessage('Upload a valid government ID.');
        return false;
      }
      if (_businessPermit == null) {
        _showMessage('Upload the business permit.');
        return false;
      }
      if (!_termsAccepted) {
        _showMessage('Accept the Terms of Service and Privacy Policy.');
        return false;
      }
      return true;
    }

    if (_orCr == null) {
      _showMessage('Upload the vehicle OR / CR.');
      return false;
    }
    if (_driverLicense == null) {
      _showMessage('Upload your driver’s license or valid ID.');
      return false;
    }
    if (!_termsAccepted) {
      _showMessage('Accept the Terms of Service and Privacy Policy.');
      return false;
    }
    return true;
  }

  Future<void> _next() async {
    if (_submitting) return;
    final ok = switch (_currentStep) {
      0 => _validatePersonal(),
      1 => _validateAddress(),
      _ => _validateFinalStep(),
    };
    if (!ok) return;

    if (_currentStep < 2) {
      _setStep(_currentStep + 1);
    } else {
      await _submitRegistration();
    }
  }

  void _setStep(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _currentStep = step);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_registrationScrollController.hasClients) {
        _registrationScrollController.jumpTo(0);
      }
    });
  }

  Future<void> _submitRegistration() async {
    if (!_emailVerified || _verificationId == null) {
      _showMessage('Verify your email address before submitting.');
      return;
    }
    setState(() {
      _submitting = true;
      _submissionError = null;
    });
    try {
      final outcome = switch (_role) {
        AccountRole.buyer => await _registration.registerBuyer(_buyerPayload()),
        AccountRole.rider => await _registration.registerRider(
          fields: _multipartFields(role: 'rider'),
          documents: [
            _document('or_cr', _orCr),
            _document('driver_license', _driverLicense),
          ],
        ),
        AccountRole.logistics => await _registration.registerLogistics(
          fields: _multipartFields(role: 'logistics'),
          documents: [
            _document('valid_id', _validId),
            _document('business_permit', _businessPermit),
          ],
        ),
      };
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouteNames.pending,
        (route) => false,
        arguments: outcome,
      );
    } catch (error) {
      if (!mounted) return;
      final message = _registrationErrorMessage(error);
      setState(() => _submissionError = message);
      _showMessage(message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Map<String, Object?> _buyerPayload() {
    final region = _regionFields.toJson();
    return {
      ..._commonPayload(),
      'sex': _apiSex(buyer: true),
      'phone_country': _phoneCountryCode,
      'city': _addressValue(cityManual, _city),
      'street_name': street.text.trim(),
      ...region,
      if (_effectiveCityCode.isNotEmpty) 'city_code': _effectiveCityCode,
    };
  }

  Map<String, String> _multipartFields({required String role}) {
    final region = _regionFields.toJson();
    return {
      ..._commonPayload().map((key, value) => MapEntry(key, '$value')),
      'sex': _apiSex(buyer: false),
      'contact_number': contact.text.trim(),
      'region': region['region'] as String,
      'region_code': region['region_code'] as String? ?? '',
      'province': _addressValue(provinceManual, _province),
      'municipality': _addressValue(cityManual, _city),
      'city_code': _effectiveCityCode,
      'barangay': _addressValue(barangayManual, _barangay),
      'street': street.text.trim(),
      'house_number': house.text.trim(),
      'postal_code': postal.text.trim(),
      'postal_manual': _postalAutoFilled ? '0' : '1',
      'terms': _termsAccepted ? '1' : '0',
      if (role == 'rider') ...{
        'logistics_partner': '${_selectedPartner!.id}',
        'work_type': _riderWorkType,
        'vehicle_type': vehicleType ?? '',
        'vehicle_model': vehicleModel.text.trim(),
        'plate_number': plateNumber.text.trim(),
      },
      if (role == 'logistics') 'business_name': businessName.text.trim(),
    };
  }

  Map<String, Object?> _commonPayload() => {
    'first_name': firstName.text.trim(),
    'middle_initial': middleInitial.text.trim(),
    'last_name': lastName.text.trim(),
    'birthday': _dateString(birthday!),
    'email': email.text.trim().toLowerCase(),
    'verification_id': _verificationId!,
    'contact_number': contact.text.trim(),
    'province': _addressValue(provinceManual, _province),
    'barangay': _addressValue(barangayManual, _barangay),
    'house_number': house.text.trim(),
    'postal_code': postal.text.trim(),
    'postal_manual': _postalAutoFilled ? '0' : '1',
    'password': password.text,
    'password_confirmation': confirmPassword.text,
    'terms': _termsAccepted ? '1' : '0',
  };

  String _apiSex({required bool buyer}) => switch (sex) {
    'Female' => buyer ? 'female' : 'Female',
    'Male' => buyer ? 'male' : 'Male',
    _ => buyer ? 'prefer_not_to_say' : 'Prefer not to say',
  };

  static String _dateString(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  ApiMultipartFile _document(String field, PlatformFile? file) {
    final bytes = file?.bytes;
    if (file == null || bytes == null || bytes.isEmpty) {
      throw const FormatException(
        'Choose each required document again before submitting.',
      );
    }
    return ApiMultipartFile(field: field, bytes: bytes, fileName: file.name);
  }

  void _back() {
    if (_currentStep > 0) _setStep(_currentStep - 1);
  }

  String _addressValue(TextEditingController manual, LocationOption? option) {
    return _manualAddress ? manual.text.trim() : (option?.name ?? '');
  }

  RegistrationRegionFields get _regionFields => RegistrationRegionFields(
    region: _manualAddress ? regionManual.text : (_region?.name ?? ''),
    regionCode: _manualAddress
        ? manualRegionCode.text.trim().isEmpty
              ? null
              : manualRegionCode.text.trim()
        : _region?.code,
  );

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      trailing: TextButton(
        onPressed: () =>
            Navigator.pushReplacementNamed(context, AppRouteNames.login),
        child: const Text('Sign in'),
      ),
      child: Column(
        children: [
          _buildProgress(),
          Expanded(
            child: ListView(
              controller: _registrationScrollController,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 120),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: switch (_currentStep) {
                      0 => _buildPersonalStep(),
                      1 => _buildAddressStep(),
                      _ =>
                        _role == AccountRole.buyer
                            ? _buildBuyerReviewStep()
                            : _isLogistics
                            ? _buildLogisticsStep()
                            : _buildRiderVehicleStep(),
                    },
                  ),
                ),
              ],
            ),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 13, 20, 13),
      decoration: const BoxDecoration(
        color: BearlyColors.cream100,
        border: Border(bottom: BorderSide(color: BearlyColors.lineSoft)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Step ${_currentStep + 1} of 3',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _stepTitle,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(
                _role.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BearlyColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentStep + 1) / 3,
            minHeight: 6,
            backgroundColor: BearlyColors.cream300,
            color: BearlyColors.brown900,
            borderRadius: BorderRadius.circular(99),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        decoration: const BoxDecoration(
          color: BearlyColors.cream50,
          border: Border(top: BorderSide(color: BearlyColors.lineSoft)),
        ),
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _back,
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _submitting ? null : _next,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _currentStep == 2
                            ? 'Submit application →'
                            : 'Continue →',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalStep() {
    return Form(
      key: _personalKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RegistrationStepHeading(
            title: "Choose how you'll use Bearly",
            subtitle: 'Choose the account you want to register.',
          ),
          const SizedBox(height: 18),
          RoleCard(
            role: AccountRole.buyer,
            selected: _role == AccountRole.buyer,
            onTap: () => _selectRole(AccountRole.buyer),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RoleCard(
                  role: AccountRole.rider,
                  selected: _role == AccountRole.rider,
                  onTap: () => _selectRole(AccountRole.rider),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RoleCard(
                  role: AccountRole.logistics,
                  selected: _role == AccountRole.logistics,
                  onTap: () => _selectRole(AccountRole.logistics),
                ),
              ),
            ],
          ),
          if (_isRider) ...[
            const SizedBox(height: 16),
            Text(
              'Rider work type',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Courier applications remain Rider accounts and use the Courier vehicle rules.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'local', label: Text('Local Rider')),
                ButtonSegment(value: 'courier', label: Text('Courier')),
              ],
              selected: {_riderWorkType},
              onSelectionChanged: (selection) => setState(() {
                _riderWorkType = selection.first;
                vehicleType = null;
              }),
            ),
          ],
          if (_isLogistics) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: businessName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Logistics business name',
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Enter your business name.';
                return text.length <= 120
                    ? null
                    : 'Use 120 characters or fewer.';
              },
            ),
          ],
          const SizedBox(height: 28),
          Text(
            'Personal Information',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Tell us a little about yourself.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: firstName,
            decoration: const InputDecoration(labelText: 'First name'),
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.givenName],
            validator: _nameValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: middleInitial,
            decoration: const InputDecoration(
              labelText: 'Middle initial (optional)',
              hintText: 'P.',
              counterText: '',
            ),
            maxLength: 2,
            inputFormatters: const [_MiddleInitialFormatter()],
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return null;
              return RegExp(r'^[A-Z]\.$').hasMatch(text)
                  ? null
                  : 'Use one letter, for example P.';
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: lastName,
            decoration: const InputDecoration(labelText: 'Last name'),
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.familyName],
            validator: _nameValidator,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: sex,
            decoration: const InputDecoration(labelText: 'Sex'),
            items: const [
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(
                value: 'Prefer not to say',
                child: Text('Prefer not to say'),
              ),
            ],
            onChanged: (value) => setState(() => sex = value),
            validator: (value) => value == null ? 'Select your sex.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            onChanged: (_) => _emailChanged(),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Enter your email address.';
              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
                  ? null
                  : 'Enter a valid email address.';
            },
          ),
          const SizedBox(height: 12),
          _buildEmailVerification(),
          const SizedBox(height: 12),
          PhoneNumberField(
            controller: contact,
            countryCode: _role == AccountRole.buyer ? _phoneCountryCode : 'PH',
            riderMode: _role != AccountRole.buyer,
            onCountryChanged: (value) => setState(() {
              _phoneCountryCode = value;
            }),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _chooseBirthday,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Birthday',
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(
                birthday == null
                    ? 'Select birthday'
                    : '${birthday!.month.toString().padLeft(2, '0')}/${birthday!.day.toString().padLeft(2, '0')}/${birthday!.year}',
                style: TextStyle(
                  color: birthday == null
                      ? BearlyColors.muted
                      : BearlyColors.text,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Age (auto-generated)',
            ),
            child: Text(_age?.toString() ?? '--'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: password,
            obscureText: !_showPassword,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            validator: _passwordValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: confirmPassword,
            obscureText: !_showConfirmPassword,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: const Icon(Icons.lock_reset_rounded),
              suffixIcon: IconButton(
                tooltip: _showConfirmPassword
                    ? 'Hide password'
                    : 'Show password',
                onPressed: () => setState(
                  () => _showConfirmPassword = !_showConfirmPassword,
                ),
                icon: Icon(
                  _showConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            validator: (value) => (value ?? '') == password.text
                ? null
                : 'Passwords do not match.',
          ),
          const SizedBox(height: 12),
          PasswordRequirements(
            password: password.text,
            confirmPassword: confirmPassword.text,
          ),
          if (_role == AccountRole.buyer) ...[
            const SizedBox(height: 12),
            _buildTermsCheckbox(),
          ],
        ],
      ),
    );
  }

  Widget _buildEmailVerification() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: BearlyColors.cream100,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: BearlyColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                color: BearlyColors.brown900,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify your email',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Bearly uses a 6-digit verification code.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _emailBusy || _retryAfterSeconds > 0
                    ? null
                    : _sendEmailCode,
                child: _emailBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _retryAfterSeconds > 0
                            ? 'Resend in ${_durationText(_retryAfterSeconds)}'
                            : _emailCodeSent
                            ? 'Resend code'
                            : 'Send code',
                      ),
              ),
            ],
          ),
          if (_emailVerified || _emailVerificationMessage != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  _emailVerified
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: _emailVerified
                      ? BearlyColors.success
                      : BearlyColors.brown700,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _emailVerificationMessage ?? 'Email address verified.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          if (_emailCodeSent) ...[
            const SizedBox(height: 12),
            TextField(
              controller: emailCode,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Verification code',
                hintText: '6-digit code',
                counterText: '',
                suffixIcon: IconButton(
                  tooltip: 'Verify email',
                  onPressed: _emailBusy || _emailVerified
                      ? null
                      : _verifyEmailCode,
                  icon: _emailBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _emailVerified
                              ? Icons.verified_rounded
                              : Icons.check_circle_outline_rounded,
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressStep() {
    return Form(
      key: _addressKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RegistrationStepHeading(
            title: 'Your address',
            subtitle:
                'Enter your Philippine address. Postal code is filled after selecting a municipality.',
          ),
          const SizedBox(height: 18),
          if (!_manualAddress) ...[
            LocationPickerField(
              label: 'Region',
              value: _region,
              items: _regions,
              enabled: !_addressLoading && _regions.isNotEmpty,
              onSelected: _loadProvinces,
            ),
            const SizedBox(height: 12),
            LocationPickerField(
              label: 'Province',
              value: _province,
              items: _provinces,
              enabled: !_addressLoading && _region != null,
              onSelected: _loadCities,
            ),
            const SizedBox(height: 12),
            LocationPickerField(
              label: 'City / Municipality',
              value: _city,
              items: _cities,
              enabled: !_addressLoading && _province != null,
              onSelected: _loadBarangays,
            ),
            const SizedBox(height: 12),
            LocationPickerField(
              label: 'Barangay',
              value: _barangay,
              items: _barangays,
              enabled: !_addressLoading && _city != null,
              onSelected: (value) => setState(() => _barangay = value),
            ),
            const SizedBox(height: 12),
            _buildAddressStatus(),
          ] else ...[
            TextFormField(
              controller: regionManual,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Region'),
              validator: RegistrationRegionFields.validateRegion,
            ),
            if (_requiresCityCode) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: manualRegionCode,
                keyboardType: TextInputType.number,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'PSGC region code',
                  hintText: '10 digits',
                  counterText: '',
                ),
                validator: (value) {
                  final code = value?.trim() ?? '';
                  if (!_requiresCityCode && code.isEmpty) return null;
                  return RegExp(r'^\d{10}$').hasMatch(code)
                      ? null
                      : 'Enter the 10-digit PSGC region code.';
                },
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: provinceManual,
              decoration: const InputDecoration(labelText: 'Province'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: cityManual,
              decoration: const InputDecoration(
                labelText: 'City / Municipality',
              ),
              validator: _requiredValidator,
            ),
            if (_requiresCityCode) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: manualCityCode,
                keyboardType: TextInputType.number,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'PSGC city / municipality code',
                  hintText: '6–10 digits',
                  counterText: '',
                ),
                onChanged: _scheduleManualPartnerLookup,
                validator: (value) {
                  final code = value?.trim() ?? '';
                  return RegExp(r'^[0-9]{6,10}$').hasMatch(code)
                      ? null
                      : 'Enter a valid 6–10 digit PSGC city code.';
                },
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: barangayManual,
              decoration: const InputDecoration(labelText: 'Barangay'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _manualAddress = false;
                  _postalAutoFilled = false;
                  _postalHint = 'Select municipality first';
                  postal.clear();
                });
                _loadRegions();
              },
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Try address service again'),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: street,
            decoration: InputDecoration(
              labelText: _role == AccountRole.rider
                  ? 'Street / Purok'
                  : 'Street name',
            ),
            validator: _requiredValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: house,
            decoration: InputDecoration(
              labelText: _role == AccountRole.rider
                  ? 'House / Building number'
                  : 'House / Unit no.',
            ),
            validator: _requiredValidator,
          ),
          if (_isRider) ...[
            const SizedBox(height: 16),
            _buildPartnerSelector(),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: postal,
            readOnly: !_manualAddress && _postalAutoFilled,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: _postalAutoFilled
                  ? 'Postal code (auto-generated)'
                  : 'Postal code',
              hintText: _postalHint,
              counterText: '',
              suffixIcon: _postalAutoFilled
                  ? const Icon(
                      Icons.check_circle_outline_rounded,
                      color: BearlyColors.success,
                    )
                  : null,
            ),
            validator: (value) {
              final code = value?.trim() ?? '';
              return RegExp(r'^\d{4}$').hasMatch(code)
                  ? null
                  : 'Enter a valid 4-digit postal code.';
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddressStatus() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BearlyColors.cream100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BearlyColors.lineSoft),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (_addressLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  _addressError == null
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  color: _addressError == null
                      ? BearlyColors.success
                      : BearlyColors.brown700,
                ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _addressLoading
                      ? 'Loading Philippine address data...'
                      : _addressError ?? 'Address service is ready.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (_addressError != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton(
                  onPressed: _loadRegions,
                  child: const Text('Retry'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _manualAddress = true;
                    _region = null;
                    _postalAutoFilled = false;
                    _postalHint = 'Enter postal code';
                    postal.clear();
                  }),
                  child: const Text('Enter manually'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPartnerSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<RegistrationPartner>(
          initialValue: _selectedPartner,
          decoration: InputDecoration(
            labelText: 'Logistics / Sorting Center',
            prefixIcon: const Icon(Icons.warehouse_outlined),
            suffixIcon: _partnersLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          items: _partners
              .map(
                (partner) => DropdownMenuItem(
                  value: partner,
                  child: Text(partner.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(growable: false),
          onChanged: _partnersLoading || _partners.isEmpty
              ? null
              : (partner) => setState(() => _selectedPartner = partner),
          validator: (partner) => partner == null
              ? 'Select an approved Logistics partner for your city.'
              : null,
        ),
        if (_partnersError != null) ...[
          const SizedBox(height: 5),
          Text(
            _partnersError!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: BearlyColors.muted),
          ),
          if (!_partnersLoading && _effectiveCityCode.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _loadLogisticsPartners(_effectiveCityCode),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry partner search'),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildBuyerReviewStep() {
    final address = _fullAddress;
    return Form(
      key: _finalKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RegistrationStepHeading(
            title: 'Review your Buyer registration',
            subtitle: 'Confirm your details and submit your verified account.',
          ),
          const SizedBox(height: 14),
          _buildApplicationSummary(address: address),
          const SizedBox(height: 16),
          const RegistrationInfoCallout(
            title: 'Email verified',
            body:
                'After submission, your Buyer account activates immediately. You can then sign in to Bearly Mobile.',
          ),
          if (_submissionError != null) ...[
            const SizedBox(height: 12),
            Text(
              _submissionError!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: BearlyColors.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRiderVehicleStep() {
    return Form(
      key: _finalKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RegistrationStepHeading(
            title: 'Vehicle & documents',
            subtitle:
                'Your selected Logistics partner will review the application before access is approved.',
          ),
          const SizedBox(height: 18),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Rider work type'),
            child: Text(
              _riderWorkType == 'courier' ? 'Courier' : 'Local Rider',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: vehicleType,
            decoration: const InputDecoration(labelText: 'Vehicle type'),
            items: _vehicleTypes
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) => setState(() => vehicleType = value),
            validator: (value) =>
                value == null ? 'Select a vehicle type.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: vehicleModel,
            textCapitalization: TextCapitalization.words,
            maxLength: 160,
            decoration: const InputDecoration(
              labelText: 'Vehicle model (optional)',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: plateNumber,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Plate number'),
            validator: _requiredValidator,
          ),
          const SizedBox(height: 14),
          DocumentUploadCard(
            title: 'Vehicle OR / CR',
            help: 'Upload a clear copy of the vehicle OR / CR.',
            file: _orCr,
            onPick: () async {
              final file = await _pickDocument();
              if (file != null) setState(() => _orCr = file);
            },
            onRemove: () => setState(() => _orCr = null),
          ),
          const SizedBox(height: 12),
          DocumentUploadCard(
            title: 'Driver’s License / Valid ID',
            help: 'Upload your driver’s license or another accepted valid ID.',
            file: _driverLicense,
            onPick: () async {
              final file = await _pickDocument();
              if (file != null) setState(() => _driverLicense = file);
            },
            onRemove: () => setState(() => _driverLicense = null),
          ),
          _buildTermsCheckbox(),
          const SizedBox(height: 16),
          _buildApplicationSummary(
            address: _fullAddress,
            extra: [
              _SummaryData('Logistics partner', _selectedPartner?.name ?? ''),
              _SummaryData(
                'Work type',
                _riderWorkType == 'courier' ? 'Courier' : 'Local Rider',
              ),
              _SummaryData('Vehicle', vehicleType ?? ''),
              _SummaryData('Vehicle model', vehicleModel.text.trim()),
              _SummaryData('Plate number', plateNumber.text.trim()),
            ],
          ),
          const SizedBox(height: 16),
          const RegistrationInfoCallout(
            title: 'Approval authority',
            body:
                'Your selected Logistics / Sorting Center reviews the Rider application before dashboard access is activated.',
          ),
        ],
      ),
    );
  }

  Widget _buildLogisticsStep() {
    return Form(
      key: _finalKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RegistrationStepHeading(
            title: 'Provider documents',
            subtitle:
                'Bearly reviews Logistics applications and required business credentials before operational access.',
          ),
          const SizedBox(height: 14),
          DocumentUploadCard(
            title: 'Valid government ID',
            help: 'Upload a clear JPG, PNG, or PDF copy (maximum 5 MB).',
            file: _validId,
            onPick: () async {
              final file = await _pickDocument();
              if (file != null) setState(() => _validId = file);
            },
            onRemove: () => setState(() => _validId = null),
          ),
          const SizedBox(height: 12),
          DocumentUploadCard(
            title: 'Business permit',
            help: 'Upload a clear JPG, PNG, or PDF copy (maximum 5 MB).',
            file: _businessPermit,
            onPick: () async {
              final file = await _pickDocument();
              if (file != null) setState(() => _businessPermit = file);
            },
            onRemove: () => setState(() => _businessPermit = null),
          ),
          const SizedBox(height: 18),
          _buildTermsCheckbox(),
          const SizedBox(height: 12),
          _buildApplicationSummary(
            address: _fullAddress,
            extra: [
              _SummaryData('Business', businessName.text.trim()),
              _SummaryData('Service area', _addressValue(cityManual, _city)),
            ],
          ),
          const SizedBox(height: 16),
          const RegistrationInfoCallout(
            title: 'Approval authority',
            body:
                'Your application and documents are reviewed by a Bearly Administrator. A Logistics operating profile is created only after approval.',
          ),
          if (_submissionError != null) ...[
            const SizedBox(height: 12),
            Text(
              _submissionError!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: BearlyColors.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: BearlyColors.brown900,
      value: _termsAccepted,
      onChanged: (value) => setState(() => _termsAccepted = value ?? false),
      title: const Text(
        'I agree to the Terms of Service and acknowledge the Privacy Policy.',
      ),
      subtitle: const Text(
        'Terms and Privacy will open as in-app legal pages when those screens are added.',
      ),
    );
  }

  Widget _buildApplicationSummary({
    required String address,
    List<_SummaryData> extra = const [],
  }) {
    final name = [
      firstName.text.trim(),
      middleInitial.text.trim(),
      lastName.text.trim(),
    ].where((item) => item.isNotEmpty).join(' ');

    final rows = [
      _SummaryData('Account type', _role.label),
      _SummaryData('Name', name),
      _SummaryData('Email', email.text.trim()),
      _SummaryData('Contact', contact.text.trim()),
      _SummaryData('Address', address),
      ...extra,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: BearlyColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Application summary',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          ...rows
              .where((row) => row.value.isNotEmpty)
              .map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 108,
                        child: Text(
                          row.label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.value,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: BearlyColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => _setStep(0),
                child: const Text('Edit personal'),
              ),
              TextButton(
                onPressed: () => _setStep(1),
                child: const Text('Edit address'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _fullAddress {
    final values = [
      house.text.trim(),
      street.text.trim(),
      _addressValue(barangayManual, _barangay),
      _addressValue(cityManual, _city),
      _addressValue(provinceManual, _province),
      _regionFields.toJson()['region'] as String,
      postal.text.trim(),
    ].where((item) => item.isNotEmpty).toList();
    return values.join(', ');
  }

  String? _nameValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'This field is required.';
    if (text.length < 2) return 'Use at least 2 characters.';
    if (text.length > 50) return 'Use 50 characters or fewer.';
    if (!RegExp(r"^[A-Za-zÀ-ÿ.' -]+$").hasMatch(text)) {
      return 'Use letters and standard name punctuation only.';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final text = value ?? '';
    final ok =
        text.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(text) &&
        RegExp(r'[a-z]').hasMatch(text) &&
        RegExp(r'\d').hasMatch(text);
    return ok
        ? null
        : 'Use 8+ characters with uppercase, lowercase, and a number.';
  }

  String? _requiredValidator(String? value) =>
      (value ?? '').trim().isEmpty ? 'This field is required.' : null;
}

class _SummaryData {
  const _SummaryData(this.label, this.value);

  final String label;
  final String value;
}

class _MiddleInitialFormatter extends TextInputFormatter {
  const _MiddleInitialFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final letters = newValue.text.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.isEmpty) return TextEditingValue.empty;
    final formatted = '${letters[0].toUpperCase()}.';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
