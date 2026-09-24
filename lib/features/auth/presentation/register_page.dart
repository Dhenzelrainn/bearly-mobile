import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../data/postal_code_service.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/bearly_theme.dart';
import '../data/psgc_service.dart';
import '../models/account_role.dart';
import '../widgets/auth_scaffold.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();
  final _psgc = const PsgcService();
  final _postalCodes = PostalCodeService();

  bool _postalAutoFilled = false;
  String _postalHint = 'Select municipality first';

  AccountRole _role = AccountRole.seller;
  int _currentStep = 1;
  bool _termsAccepted = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _manualAddress = false;
  bool _addressLoading = true;
  String? _addressError;

  List<LocationOption> _provinces = const [];
  List<LocationOption> _cities = const [];
  List<LocationOption> _barangays = const [];
  LocationOption? _province;
  LocationOption? _city;
  LocationOption? _barangay;

  PlatformFile? _validId;
  PlatformFile? _businessPermit;
  PlatformFile? _orCr;

  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final middleInitial = TextEditingController();
  String? sex;
  final email = TextEditingController();
  final contact = TextEditingController();
  DateTime? birthday;
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  final provinceManual = TextEditingController();
  final cityManual = TextEditingController();
  final barangayManual = TextEditingController();
  final street = TextEditingController();
  final house = TextEditingController();
  final postal = TextEditingController();

  final businessName = TextEditingController();
  String? businessCategory;
  String? vehicleType;
  final plateNumber = TextEditingController();
  final logisticsName = TextEditingController();

  static const _businessCategories = [
    'Pet Supplies',
    'Electronics and Gadgets',
    "Women's Apparel",
    "Men's Apparel",
    'Kids and Baby',
    'Home and Garden',
    'Sports and Outdoors',
    'Health and Beauty',
    'Books and Media',
    'Food and Gourmet',
    'Furniture and Office Equipment',
    'Jewelry and Watches',
  ];

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  @override
  void dispose() {
    for (final controller in [
      firstName,
      lastName,
      middleInitial,
      email,
      contact,
      password,
      confirmPassword,
      provinceManual,
      cityManual,
      barangayManual,
      street,
      house,
      postal,
      businessName,
      plateNumber,
      logisticsName,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<int> get _activeSteps => _role == AccountRole.buyer ? [1, 2, 4] : [1, 2, 3, 4];

  int? get _age {
    if (birthday == null) return null;
    final now = DateTime.now();
    var years = now.year - birthday!.year;
    if (now.isBefore(DateTime(now.year, birthday!.month, birthday!.day))) years--;
    if (years < 0) return 0;
    if (years > 150) return 150;
    return years;
  }

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
        _addressError = 'Address service is unavailable. Retry or enter the address manually.';
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

      if (!mounted) return;

      // Ignore stale lookup results if the user changed the municipality.
      if (_city?.code != city.code) return;

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

    // Postal code is based on province + city/municipality.
    await _updatePostalCode(city);

    try {
      final data = await _psgc.barangays(city.code);
      if (!mounted) return;

      // Ignore stale barangay results if another municipality was selected.
      if (_city?.code != city.code) return;

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

  bool _validateCurrentStep() {
    if (_currentStep == 1) {
      final valid = _step1Key.currentState?.validate() ?? false;
      if (!_termsAccepted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accept the Terms of Service and Privacy Policy to continue.')),
        );
        return false;
      }
      return valid;
    }

    if (_currentStep == 2) {
      final valid = _step2Key.currentState?.validate() ?? false;
      if (!valid) return false;
      if (!_manualAddress && (_province == null || _city == null || _barangay == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complete your province, city, and barangay.')),
        );
        return false;
      }
      return true;
    }

    if (_currentStep == 3) return _step3Key.currentState?.validate() ?? false;

    if (_currentStep == 4) {
      if (_validId == null) return _documentError('Upload a valid government ID.');
      if ((_role == AccountRole.seller || _role == AccountRole.logistics) && _businessPermit == null) {
        return _documentError('Upload the required business permit.');
      }
      if (_role == AccountRole.rider && _orCr == null) return _documentError('Upload the vehicle OR / CR.');
    }
    return true;
  }

  bool _documentError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    return false;
  }

  void _next() {
    if (!_validateCurrentStep()) return;
    final index = _activeSteps.indexOf(_currentStep);
    if (index < _activeSteps.length - 1) setState(() => _currentStep = _activeSteps[index + 1]);
  }

  void _back() {
    final index = _activeSteps.indexOf(_currentStep);
    if (index > 0) setState(() => _currentStep = _activeSteps[index - 1]);
  }

  Future<void> _chooseBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: birthday ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => birthday = picked);
  }

  Future<PlatformFile?> _pickDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'pdf' , 'webp'],
      allowMultiple: false,
      withData: false,
    );
    if (result == null) return null;
    final file = result.files.single;
    if (file.size > 5 * 1024 * 1024) {
      _documentError('The file must not exceed 5 MB.');
      return null;
    }
    return file;
  }

  void _submitPreview() {
    if (!_validateCurrentStep()) return;
    Navigator.pushNamed(context, AppRoutes.pending, arguments: _role.label);
  }

  String _addressValue(TextEditingController manual, LocationOption? option) {
    return _manualAddress ? manual.text.trim() : (option?.name ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final stepIndex = _activeSteps.indexOf(_currentStep);
    return AuthScaffold(
      trailing: TextButton(
        onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
        child: const Text('Sign in'),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            decoration: const BoxDecoration(
              color: BearlyColors.cream100,
              border: Border(bottom: BorderSide(color: BearlyColors.lineSoft)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('Step ${stepIndex + 1} of ${_activeSteps.length}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(_role.label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BearlyColors.gold, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (stepIndex + 1) / _activeSteps.length,
                  minHeight: 6,
                  backgroundColor: BearlyColors.cream300,
                  color: BearlyColors.brown900,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 120),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: switch (_currentStep) {
                      1 => _buildPersonalStep(),
                      2 => _buildAddressStep(),
                      3 => _buildRoleStep(),
                      4 => _buildDocumentsStep(),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              decoration: const BoxDecoration(
                color: BearlyColors.cream50,
                border: Border(top: BorderSide(color: BearlyColors.lineSoft)),
              ),
              child: Row(
                children: [
                  if (_currentStep != _activeSteps.first) ...[
                    Expanded(child: OutlinedButton(onPressed: _back, child: const Text('Back'))),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _currentStep == 4 ? _submitPreview : _next,
                      child: Text(_currentStep == 4 ? 'Submit application →' : 'Continue →'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalStep() {
    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepTitle(title: "Choose how you'll use Bearly", subtitle: 'Join Bearly as a buyer, seller, rider, or logistics partner.'),
          const SizedBox(height: 18),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.2,
            children: AccountRole.values.map((role) {
              final selected = role == _role;
              return InkWell(
                onTap: () => setState(() => _role = role),
                borderRadius: BorderRadius.circular(17),
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? BearlyColors.brown900 : Colors.white,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: selected ? BearlyColors.brown900 : BearlyColors.lineSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(role.icon, color: selected ? Colors.white : BearlyColors.brown900, size: 28),
                      const Spacer(),
                      Text(role.label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: selected ? Colors.white : BearlyColors.text)),
                      const SizedBox(height: 3),
                      Text(
                        role.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: selected ? Colors.white.withValues(alpha: 0.78) : BearlyColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          Text('Personal Information', style: Theme.of(context).textTheme.titleLarge),
          Text('Tell us a little about yourself', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          TextFormField(controller: firstName, decoration: const InputDecoration(labelText: 'First name'), textCapitalization: TextCapitalization.words, validator: _nameValidator),
          const SizedBox(height: 12),
          TextFormField(controller: lastName, decoration: const InputDecoration(labelText: 'Last name'), textCapitalization: TextCapitalization.words, validator: _nameValidator),
          const SizedBox(height: 12),
          TextFormField(
            controller: middleInitial,
            decoration: const InputDecoration(labelText: 'Middle initial (optional)', counterText: ''),
            textCapitalization: TextCapitalization.characters,
            maxLength: 2,
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return null;
              return RegExp(r'^[A-Za-z][.]?$').hasMatch(text) ? null : 'Use P or P.';
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: sex,
            decoration: const InputDecoration(labelText: 'Sex'),
            items: const [
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'prefer_not_to_say', child: Text('Prefer not to say')),
            ],
            onChanged: (value) => setState(() => sex = value),
            validator: (value) => value == null ? 'Select your sex.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address'),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Enter your email address.';
              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text) ? null : 'Enter a valid email.';
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: contact,
            keyboardType: TextInputType.phone,
            maxLength: 13,
            decoration: const InputDecoration(labelText: 'Contact number', hintText: '09XXXXXXXXX', counterText: ''),
            validator: (value) => RegExp(r'^(?:\+639|09)\d{9}$').hasMatch((value ?? '').trim()) ? null : 'Use 09XXXXXXXXX or +639XXXXXXXXX.',
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _chooseBirthday,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Birthday', suffixIcon: Icon(Icons.calendar_today_outlined)),
              child: Text(
                birthday == null ? 'Select birthday' : '${birthday!.month.toString().padLeft(2, '0')}/${birthday!.day.toString().padLeft(2, '0')}/${birthday!.year}',
                style: TextStyle(color: birthday == null ? BearlyColors.muted : BearlyColors.text),
              ),
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(decoration: const InputDecoration(labelText: 'Age (auto-generated)'), child: Text(_age?.toString() ?? '--')),
          const SizedBox(height: 12),
          TextFormField(
            controller: password,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              ),
            ),
            validator: (value) {
              final text = value ?? '';
              final ok = text.length >= 8 && RegExp(r'[A-Z]').hasMatch(text) && RegExp(r'[a-z]').hasMatch(text) && RegExp(r'\d').hasMatch(text);
              return ok ? null : 'Use 8+ chars with upper, lower, and a number.';
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: confirmPassword,
            obscureText: !_showConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm password',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                icon: Icon(_showConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              ),
            ),
            validator: (value) => (value ?? '') == password.text ? null : 'Passwords do not match.',
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: BearlyColors.brown900,
            value: _termsAccepted,
            onChanged: (value) => setState(() => _termsAccepted = value ?? false),
            title: const Text('I agree to the Terms of Service and Privacy Policy.'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressStep() {
    return Form(
      key: _step2Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepTitle(title: 'Your address', subtitle: 'Tell us where you are located.'),
          const SizedBox(height: 18),
          if (!_manualAddress) ...[
            _LocationField(label: 'Province', value: _province, items: _provinces, enabled: !_addressLoading && _provinces.isNotEmpty, onSelected: _loadCities),
            const SizedBox(height: 12),
            _LocationField(label: 'City / Municipality', value: _city, items: _cities, enabled: !_addressLoading && _province != null, onSelected: _loadBarangays),
            const SizedBox(height: 12),
            _LocationField(label: 'Barangay', value: _barangay, items: _barangays, enabled: !_addressLoading && _city != null, onSelected: (value) => setState(() => _barangay = value)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: BearlyColors.cream100, borderRadius: BorderRadius.circular(14), border: Border.all(color: BearlyColors.lineSoft)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_addressLoading)
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        Icon(_addressError == null ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded, color: _addressError == null ? BearlyColors.success : BearlyColors.brown700),
                      const SizedBox(width: 9),
                      Expanded(child: Text(_addressLoading ? 'Loading Philippine address data...' : _addressError ?? 'Address service is ready.', style: Theme.of(context).textTheme.bodySmall)),
                    ],
                  ),
                  if (_addressError != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(onPressed: _loadProvinces, child: const Text('Retry')),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _manualAddress = true;
                              _postalAutoFilled = false;
                              _postalHint = 'Enter postal code';
                              postal.clear();
                            });
                          },
                          child: const Text('Enter manually'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            TextFormField(controller: provinceManual, decoration: const InputDecoration(labelText: 'Province'), validator: _requiredValidator),
            const SizedBox(height: 12),
            TextFormField(controller: cityManual, decoration: const InputDecoration(labelText: 'City / Municipality'), validator: _requiredValidator),
            const SizedBox(height: 12),
            TextFormField(controller: barangayManual, decoration: const InputDecoration(labelText: 'Barangay'), validator: _requiredValidator),
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
          const SizedBox(height: 18),
          TextFormField(controller: street, decoration: const InputDecoration(labelText: 'Street name'), validator: _requiredValidator),
          const SizedBox(height: 12),
          TextFormField(controller: house, decoration: const InputDecoration(labelText: 'House / Unit no.'), validator: _requiredValidator),
          const SizedBox(height: 12),
          TextFormField(
            controller: postal,
            readOnly: !_manualAddress && _postalAutoFilled,
            keyboardType: TextInputType.number,
            maxLength: 4,
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

  Widget _buildRoleStep() {
    return Form(
      key: _step3Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepTitle(
            title: _role.detailStepTitle,
            subtitle: switch (_role) {
              AccountRole.seller => 'Provide the information used to verify your seller account.',
              AccountRole.rider => 'Provide the vehicle information used for parcel pickup and delivery.',
              AccountRole.logistics => 'Provide your Logistics / Sorting Center information.',
              AccountRole.buyer => 'Buyer accounts skip this step.',
            },
          ),
          const SizedBox(height: 18),
          if (_role == AccountRole.seller) ...[
            TextFormField(controller: businessName, decoration: const InputDecoration(labelText: 'Business name'), validator: _requiredValidator),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: businessCategory,
              decoration: const InputDecoration(labelText: 'Line of business'),
              items: _businessCategories.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (value) => setState(() => businessCategory = value),
              validator: (value) => value == null ? 'Select a business category.' : null,
            ),
            const SizedBox(height: 16),
            const _InfoCallout(title: 'Admin review required.', body: 'We’ll email the decision before Seller Dashboard access is enabled.'),
          ],
          if (_role == AccountRole.rider) ...[
            DropdownButtonFormField<String>(
              value: vehicleType,
              decoration: const InputDecoration(labelText: 'Vehicle type'),
              items: const ['Motorcycle', 'Car', 'Van', 'Truck'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (value) => setState(() => vehicleType = value),
              validator: (value) => value == null ? 'Select your vehicle type.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: plateNumber, decoration: const InputDecoration(labelText: 'Plate number', hintText: 'ABC 1234'), validator: _requiredValidator),
            const SizedBox(height: 16),
            const _InfoCallout(title: 'Logistics review required.', body: 'A Logistics / Sorting Center will review your Rider application.'),
          ],
          if (_role == AccountRole.logistics) ...[
            TextFormField(controller: logisticsName, decoration: const InputDecoration(labelText: 'Business / logistics center name'), validator: _requiredValidator),
            const SizedBox(height: 16),
            const _InfoCallout(title: 'Admin review required.', body: 'Your Logistics / Sorting Center application will be reviewed before dashboard access is enabled.'),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentsStep() {
    final address = [
      house.text.trim(),
      street.text.trim(),
      _addressValue(barangayManual, _barangay),
      _addressValue(cityManual, _city),
      _addressValue(provinceManual, _province),
      postal.text.trim(),
    ].where((item) => item.isNotEmpty).join(', ');

    final roleDetails = switch (_role) {
      AccountRole.seller => businessName.text.trim(),
      AccountRole.rider => '${vehicleType ?? ''} ${plateNumber.text.trim()}'.trim(),
      AccountRole.logistics => logisticsName.text.trim(),
      AccountRole.buyer => '',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(title: 'Documents & review', subtitle: 'Upload the required documents and confirm your application.'),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.shield_outlined, color: BearlyColors.brown900),
            const SizedBox(width: 10),
            Expanded(child: Text('Documents stay local in this preview until backend upload is connected.', style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
        const SizedBox(height: 16),
        _DocumentCard(
          title: _role == AccountRole.rider ? 'Valid ID or driver’s license' : 'Valid government ID',
          file: _validId,
          onPick: () async {
            final file = await _pickDocument();
            if (file != null) setState(() => _validId = file);
          },
          onRemove: () => setState(() => _validId = null),
        ),
        if (_role == AccountRole.seller || _role == AccountRole.logistics) ...[
          const SizedBox(height: 12),
          _DocumentCard(
            title: _role == AccountRole.logistics ? 'Business / DTI permit' : 'Business permit',
            file: _businessPermit,
            onPick: () async {
              final file = await _pickDocument();
              if (file != null) setState(() => _businessPermit = file);
            },
            onRemove: () => setState(() => _businessPermit = null),
          ),
        ],
        if (_role == AccountRole.rider) ...[
          const SizedBox(height: 12),
          _DocumentCard(
            title: 'OR / CR',
            file: _orCr,
            onPick: () async {
              final file = await _pickDocument();
              if (file != null) setState(() => _orCr = file);
            },
            onRemove: () => setState(() => _orCr = null),
          ),
        ],
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: BearlyColors.lineSoft)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Application summary', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              _SummaryRow(label: 'Account type', value: _role.label),
              _SummaryRow(label: 'Name', value: [firstName.text.trim(), middleInitial.text.trim(), lastName.text.trim()].where((e) => e.isNotEmpty).join(' ')),
              _SummaryRow(label: 'Email', value: email.text.trim()),
              _SummaryRow(label: 'Contact', value: contact.text.trim()),
              _SummaryRow(label: 'Address', value: address),
              if (roleDetails.isNotEmpty) _SummaryRow(label: _role.detailStepTitle, value: roleDetails),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(onPressed: () => setState(() => _currentStep = 1), child: const Text('Edit personal')),
                  TextButton(onPressed: () => setState(() => _currentStep = 2), child: const Text('Edit address')),
                  if (_role.requiresRoleDetails) TextButton(onPressed: () => setState(() => _currentStep = 3), child: const Text('Edit role details')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _InfoCallout(
          title: 'What happens next?',
          body: _role == AccountRole.rider
              ? 'A Logistics / Sorting Center will review the Rider application once backend submission is connected.'
              : 'An administrator will review the ${_role.label} application once backend submission is connected.',
        ),
      ],
    );
  }

  String? _nameValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'This field is required.';
    if (RegExp(r'\d').hasMatch(text)) return 'Names cannot contain numbers.';
    return null;
  }

  String? _requiredValidator(String? value) => (value ?? '').trim().isEmpty ? 'This field is required.' : null;
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: BearlyColors.muted)),
      ],
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({required this.label, required this.value, required this.items, required this.enabled, required this.onSelected});
  final String label;
  final LocationOption? value;
  final List<LocationOption> items;
  final bool enabled;
  final ValueChanged<LocationOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled
          ? () async {
              final result = await showModalBottomSheet<LocationOption>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                backgroundColor: BearlyColors.cream50,
                builder: (_) => _LocationPickerSheet(title: label, items: items, selected: value),
              );
              if (result != null) onSelected(result);
            }
          : null,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, enabled: enabled, suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded)),
        child: Text(value?.name ?? (enabled ? 'Select $label' : 'Loading...'), style: TextStyle(color: value == null ? BearlyColors.muted : BearlyColors.text)),
      ),
    );
  }
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({required this.title, required this.items, required this.selected});
  final String title;
  final List<LocationOption> items;
  final LocationOption? selected;

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final filtered = widget.items.where((item) => q.isEmpty || item.name.toLowerCase().contains(q)).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.76,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            TextField(autofocus: true, onChanged: (value) => setState(() => query = value), decoration: InputDecoration(hintText: 'Search ${widget.title.toLowerCase()}', prefixIcon: const Icon(Icons.search_rounded))),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    trailing: item.code == widget.selected?.code ? const Icon(Icons.check_rounded, color: BearlyColors.brown900) : null,
                    onTap: () => Navigator.pop(context, item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.title, required this.file, required this.onPick, required this.onRemove});
  final String title;
  final PlatformFile? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: BearlyColors.lineSoft), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: BearlyColors.brown900),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              const Text('Required', style: TextStyle(color: BearlyColors.brown700, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 7),
          Text('PNG, JPG, or PDF · Max 5 MB', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          if (file == null)
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: onPick, icon: const Icon(Icons.cloud_upload_outlined), label: const Text('Choose file')))
          else
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(color: BearlyColors.cream100, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: BearlyColors.success),
                  const SizedBox(width: 9),
                  Expanded(child: Text(file!.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  IconButton(onPressed: onPick, icon: const Icon(Icons.sync_rounded)),
                  IconButton(onPressed: onRemove, icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
        ],
      ),
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
      decoration: BoxDecoration(color: BearlyColors.cream100, borderRadius: BorderRadius.circular(14), border: Border.all(color: BearlyColors.lineSoft)),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            TextSpan(text: '$title ', style: const TextStyle(color: BearlyColors.brown900, fontWeight: FontWeight.w700)),
            TextSpan(text: body),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 104, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BearlyColors.text, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
