import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/bearly_theme.dart';
import '../data/postal_code_service.dart';
import '../data/psgc_service.dart';
import '../models/account_role.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/document_source_sheet.dart';
import '../widgets/document_upload_card.dart';
import '../widgets/location_picker_sheet.dart';
import '../widgets/password_requirements.dart';
import '../widgets/phone_number_field.dart';
import '../widgets/role_card.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _personalKey = GlobalKey<FormState>();
  final _addressKey = GlobalKey<FormState>();
  final _finalKey = GlobalKey<FormState>();

  final _psgc = const PsgcService();
  final _postalCodes = PostalCodeService();
  final _imagePicker = ImagePicker();

  AccountRole _role = AccountRole.buyer;
  int _currentStep = 0;

  bool _termsAccepted = false;
  bool _riderCertification = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _emailCodeSent = false;

  bool _manualAddress = false;
  bool _addressLoading = true;
  String? _addressError;
  bool _postalAutoFilled = false;
  String _postalHint = 'Select municipality first';

  List<LocationOption> _provinces = const [];
  List<LocationOption> _cities = const [];
  List<LocationOption> _barangays = const [];
  LocationOption? _province;
  LocationOption? _city;
  LocationOption? _barangay;

  PlatformFile? _validId;
  PlatformFile? _orCr;
  PlatformFile? _driverLicense;

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

  final provinceManual = TextEditingController();
  final cityManual = TextEditingController();
  final barangayManual = TextEditingController();
  final street = TextEditingController();
  final house = TextEditingController();
  final postal = TextEditingController();

  final logisticsPartner = TextEditingController();
  String? vehicleType;
  final plateNumber = TextEditingController();

  static const _vehicleTypes = [
    'Motorcycle',
    'Tricycle',
    'E-bike',
    'Van',
  ];

  @override
  void initState() {
    super.initState();
    _loadProvinces();
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
      provinceManual,
      cityManual,
      barangayManual,
      street,
      house,
      postal,
      logisticsPartner,
      plateNumber,
    ]) {
      controller.dispose();
    }
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
        _ => _role == AccountRole.buyer
            ? 'Documents & Review'
            : 'Vehicle & Documents',
      };

  Future<void> _loadProvinces() async {
    setState(() {
      _addressLoading = true;
      _addressError = null;
    });
    try {
      final data = await _psgc.provinces();
      if (!mounted) return;
      setState(() {
        _provinces = data;
        _addressLoading = false;
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

  Future<void> _loadCities(LocationOption province) async {
    setState(() {
      _province = province;
      _city = null;
      _barangay = null;
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
      _barangays = const [];
      postal.clear();
      _postalAutoFilled = false;
      _postalHint = 'Looking up postal code...';
      _addressLoading = true;
      _addressError = null;
    });

    await _updatePostalCode(city);

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
        withData: false,
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
        _showMessage('Choose a JPG or PNG image, or upload the document as PDF.');
        return null;
      }

      file = PlatformFile(
        name: image.name,
        size: await image.length(),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _sendEmailCode() {
    final value = email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      _showMessage('Enter a valid email address first.');
      return;
    }
    setState(() => _emailCodeSent = true);
    _showMessage(
      'Email verification UI is ready. Sending the real 6-digit code requires the Laravel mobile auth API.',
    );
  }

  void _verifyEmailCode() {
    final code = emailCode.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showMessage('Enter the 6-digit verification code.');
      return;
    }
    _showMessage(
      'The code will be verified by Laravel once the mobile auth API is connected.',
    );
  }

  bool _validatePersonal() {
    final valid = _personalKey.currentState?.validate() ?? false;
    if (!valid) return false;

    if (birthday == null) {
      _showMessage('Select your birthday.');
      return false;
    }

    if (_role == AccountRole.buyer && !_termsAccepted) {
      _showMessage('Accept the Terms of Service and Privacy Policy to continue.');
      return false;
    }

    return true;
  }

  bool _validateAddress() {
    final valid = _addressKey.currentState?.validate() ?? false;
    if (!valid) return false;

    if (!_manualAddress &&
        (_province == null || _city == null || _barangay == null)) {
      _showMessage('Complete your province, municipality, and barangay.');
      return false;
    }
    return true;
  }

  bool _validateFinalStep() {
    final valid = _finalKey.currentState?.validate() ?? false;
    if (!valid) return false;

    if (_role == AccountRole.buyer) {
      if (_validId == null) {
        _showMessage('Upload a valid government ID.');
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
    if (!_riderCertification) {
      _showMessage('Certify that the Rider and vehicle details are accurate.');
      return false;
    }
    if (!_termsAccepted) {
      _showMessage('Accept the Terms of Service and Privacy Policy.');
      return false;
    }
    return true;
  }

  void _next() {
    final ok = switch (_currentStep) {
      0 => _validatePersonal(),
      1 => _validateAddress(),
      _ => _validateFinalStep(),
    };
    if (!ok) return;

    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      Navigator.pushNamed(
        context,
        AppRoutes.pending,
        arguments: _role.label,
      );
    }
  }

  void _back() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  String _addressValue(TextEditingController manual, LocationOption? option) {
    return _manualAddress ? manual.text.trim() : (option?.name ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      trailing: TextButton(
        onPressed: () => Navigator.pushReplacementNamed(
          context,
          AppRoutes.login,
        ),
        child: const Text('Sign in'),
      ),
      child: Column(
        children: [
          _buildProgress(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 120),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: switch (_currentStep) {
                      0 => _buildPersonalStep(),
                      1 => _buildAddressStep(),
                      _ => _role == AccountRole.buyer
                          ? _buildBuyerReviewStep()
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
                onPressed: _next,
                child: Text(
                  _currentStep == 2 ? 'Submit application →' : 'Continue →',
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
          const _StepHeading(
            title: "Choose how you'll use Bearly",
            subtitle: 'The Bearly mobile app supports Buyer and Rider accounts.',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: RoleCard(
                  role: AccountRole.buyer,
                  selected: _role == AccountRole.buyer,
                  onTap: () => setState(() {
                    _role = AccountRole.buyer;
                    _phoneCountryCode = 'PH';
                    contact.clear();
                    _termsAccepted = false;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RoleCard(
                  role: AccountRole.rider,
                  selected: _role == AccountRole.rider,
                  onTap: () => setState(() {
                    _role = AccountRole.rider;
                    _phoneCountryCode = 'PH';
                    contact.clear();
                    _termsAccepted = false;
                  }),
                ),
              ),
            ],
          ),
          if (_role == AccountRole.rider) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: logisticsPartner,
              decoration: const InputDecoration(
                labelText: 'Logistics / Sorting Center',
                hintText: 'Select approved partner when API is connected',
                prefixIcon: Icon(Icons.warehouse_outlined),
              ),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 6),
            Text(
              'The production app will load approved Logistics partners from Laravel.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 28),
          Text('Personal Information', style: Theme.of(context).textTheme.titleLarge),
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
            value: sex,
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
            onChanged: (_) {
              if (_emailCodeSent) setState(() => _emailCodeSent = false);
            },
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
            countryCode: _role == AccountRole.rider ? 'PH' : _phoneCountryCode,
            riderMode: _role == AccountRole.rider,
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
                  color: birthday == null ? BearlyColors.muted : BearlyColors.text,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Age (auto-generated)'),
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
                onPressed: _sendEmailCode,
                child: const Text('Send code'),
              ),
            ],
          ),
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
                  onPressed: _verifyEmailCode,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'The real send/verify action will use Laravel’s email verification API.',
              style: Theme.of(context).textTheme.bodySmall,
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
          const _StepHeading(
            title: 'Your address',
            subtitle:
                'Enter your Philippine address. Postal code is filled after selecting a municipality.',
          ),
          const SizedBox(height: 18),
          if (!_manualAddress) ...[
            LocationPickerField(
              label: 'Province',
              value: _province,
              items: _provinces,
              enabled: !_addressLoading && _provinces.isNotEmpty,
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
              controller: provinceManual,
              decoration: const InputDecoration(labelText: 'Province'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: cityManual,
              decoration: const InputDecoration(labelText: 'City / Municipality'),
              validator: _requiredValidator,
            ),
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
                _loadProvinces();
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
                  onPressed: _loadProvinces,
                  child: const Text('Retry'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _manualAddress = true;
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

  Widget _buildBuyerReviewStep() {
    final address = _fullAddress;
    return Form(
      key: _finalKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeading(
            title: 'Documents & review',
            subtitle: 'Upload your ID and confirm the application details.',
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BearlyColors.cream100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BearlyColors.lineSoft),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: BearlyColors.brown900,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Use a current government-issued ID. Keep all four corners visible and make sure the name and photo are readable.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DocumentUploadCard(
            title: 'Valid government ID',
            help:
                'Passport, driver’s license, national ID, or another government-issued ID.',
            file: _validId,
            onPick: () async {
              final file = await _pickDocument();
              if (file != null) setState(() => _validId = file);
            },
            onRemove: () => setState(() => _validId = null),
          ),
          const SizedBox(height: 22),
          _buildApplicationSummary(address: address),
          const SizedBox(height: 16),
          const _InfoCallout(
            title: 'What happens next?',
            body:
                'A Bearly administrator will review your Buyer application. Buyer access becomes available after approval.',
          ),
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
          const _StepHeading(
            title: 'Vehicle & documents',
            subtitle:
                'Your selected Logistics / Sorting Center will review these credentials.',
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            value: vehicleType,
            decoration: const InputDecoration(labelText: 'Vehicle type'),
            items: _vehicleTypes
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) => setState(() => vehicleType = value),
            validator: (value) => value == null ? 'Select a vehicle type.' : null,
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
          const SizedBox(height: 14),
          CheckboxListTile(
            value: _riderCertification,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: BearlyColors.brown900,
            onChanged: (value) => setState(
              () => _riderCertification = value ?? false,
            ),
            title: const Text(
              'I certify that these Rider and vehicle details are accurate.',
            ),
            subtitle: const Text(
              'The selected Logistics partner will verify every document.',
            ),
          ),
          _buildTermsCheckbox(),
          const SizedBox(height: 16),
          _buildApplicationSummary(
            address: _fullAddress,
            extra: [
              _SummaryData('Logistics partner', logisticsPartner.text.trim()),
              _SummaryData('Vehicle', vehicleType ?? ''),
              _SummaryData('Plate number', plateNumber.text.trim()),
            ],
          ),
          const SizedBox(height: 16),
          const _InfoCallout(
            title: 'Approval authority',
            body:
                'Your selected Logistics / Sorting Center reviews the Rider application before dashboard access is activated.',
          ),
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
          Text('Application summary', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          ...rows.where((row) => row.value.isNotEmpty).map(
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
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                onPressed: () => setState(() => _currentStep = 0),
                child: const Text('Edit personal'),
              ),
              TextButton(
                onPressed: () => setState(() => _currentStep = 1),
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
      postal.text.trim(),
    ].where((item) => item.isNotEmpty).toList();
    return values.join(', ');
  }

  String? _nameValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'This field is required.';
    if (!RegExp(r"^[A-Za-zÀ-ÿ.' -]+$").hasMatch(text)) {
      return 'Use letters and standard name punctuation only.';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final text = value ?? '';
    final ok = text.length >= 8 &&
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

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: BearlyColors.muted,
              ),
        ),
      ],
    );
  }
}

class _InfoCallout extends StatelessWidget {
  const _InfoCallout({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: BearlyColors.cream100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BearlyColors.lineSoft),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            TextSpan(
              text: '$title ',
              style: const TextStyle(
                color: BearlyColors.brown900,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: body),
          ],
        ),
      ),
    );
  }
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
