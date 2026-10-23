import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/bearly_theme.dart';
import '../data/buyer_address_controller.dart';
import '../data/buyer_location_repository.dart';
import '../models/buyer_shopping_models.dart';

class BuyerAddressFormPage extends StatefulWidget {
  const BuyerAddressFormPage({
    super.key,
    required this.controller,
    required this.locationRepository,
    this.address,
  });

  final BuyerAddressController controller;
  final BuyerLocationRepository locationRepository;
  final BuyerAddress? address;

  @override
  State<BuyerAddressFormPage> createState() => _BuyerAddressFormPageState();
}

class _BuyerAddressFormPageState extends State<BuyerAddressFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _province;
  late final TextEditingController _city;
  late final TextEditingController _barangay;
  late final TextEditingController _street;
  late final TextEditingController _postal;

  List<BuyerLocationOption> _provinces = const [];
  List<BuyerLocationOption> _cities = const [];
  List<BuyerLocationOption> _barangays = const [];
  List<BuyerPostalCodeOption> _postalOptions = const [];
  BuyerLocationOption? _selectedProvince;
  BuyerLocationOption? _selectedCity;
  BuyerLocationOption? _selectedBarangay;
  String _label = 'Home';
  Object? _provinceError;
  Object? _cityError;
  Object? _barangayError;
  Object? _postalError;
  String? _generalError;
  Map<String, String> _fieldErrors = {};
  int _provinceSequence = 0;
  int _citySequence = 0;
  int _barangaySequence = 0;
  int _postalSequence = 0;
  bool _loadingProvinces = false;
  bool _loadingCities = false;
  bool _loadingBarangays = false;
  bool _loadingPostal = false;
  bool _submitting = false;

  BuyerAddress? get _address => widget.address;
  bool get _isEditing => _address != null;

  bool get _isDirty {
    final original = _address;
    if (original == null) {
      return _name.text.isNotEmpty ||
          _phone.text.isNotEmpty ||
          _province.text.isNotEmpty ||
          _city.text.isNotEmpty ||
          _barangay.text.isNotEmpty ||
          _street.text.isNotEmpty ||
          _postal.text.isNotEmpty ||
          _label != 'Home';
    }
    return _name.text != original.name ||
        _phone.text != original.phone ||
        _province.text != original.province ||
        _city.text != original.city ||
        _barangay.text != original.barangay ||
        _street.text != original.street ||
        _postal.text != original.postal ||
        _label != original.label;
  }

  @override
  void initState() {
    super.initState();
    final address = _address;
    _name = TextEditingController(text: address?.name ?? '');
    _phone = TextEditingController(text: address?.phone ?? '');
    _province = TextEditingController(text: address?.province ?? '');
    _city = TextEditingController(text: address?.city ?? '');
    _barangay = TextEditingController(text: address?.barangay ?? '');
    _street = TextEditingController(text: address?.street ?? '');
    _postal = TextEditingController(text: address?.postal ?? '');
    _label = address?.label == 'Work' ? 'Work' : 'Home';
    unawaited(_loadProvinces(resolveSavedAddress: address != null));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _province.dispose();
    _city.dispose();
    _barangay.dispose();
    _street.dispose();
    _postal.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces({bool resolveSavedAddress = false}) async {
    final sequence = ++_provinceSequence;
    setState(() {
      _loadingProvinces = true;
      _provinceError = null;
    });
    try {
      final options = await widget.locationRepository.fetchProvinces();
      if (!mounted || sequence != _provinceSequence) return;
      setState(() => _provinces = options);
      if (resolveSavedAddress && _address != null) {
        final match = _uniqueLocationMatch(options, _address!.province);
        if (match != null) {
          setState(() => _selectedProvince = match);
          await _loadCities(match.code, resolveSavedAddress: true);
        }
      }
    } catch (error) {
      if (mounted && sequence == _provinceSequence) {
        setState(() => _provinceError = error);
      }
    } finally {
      if (mounted && sequence == _provinceSequence) {
        setState(() => _loadingProvinces = false);
      }
    }
  }

  Future<void> _loadCities(
    String provinceCode, {
    bool resolveSavedAddress = false,
  }) async {
    final sequence = ++_citySequence;
    setState(() {
      _loadingCities = true;
      _cityError = null;
    });
    try {
      final options = await widget.locationRepository.fetchCities(provinceCode);
      if (!mounted ||
          sequence != _citySequence ||
          _selectedProvince?.code != provinceCode) {
        return;
      }
      setState(() => _cities = options);
      if (resolveSavedAddress && _address != null) {
        final match = _uniqueLocationMatch(options, _address!.city);
        if (match != null) {
          setState(() => _selectedCity = match);
          await Future.wait([
            _loadBarangays(match.code, resolveSavedAddress: true),
            _loadPostalCodes(cityCode: match.code),
          ]);
        } else {
          await _loadPostalCodes(
            province: _address!.province,
            city: _address!.city,
          );
        }
      }
    } catch (error) {
      if (mounted && sequence == _citySequence) {
        setState(() => _cityError = error);
      }
    } finally {
      if (mounted && sequence == _citySequence) {
        setState(() => _loadingCities = false);
      }
    }
  }

  Future<void> _loadBarangays(
    String cityCode, {
    bool resolveSavedAddress = false,
  }) async {
    final sequence = ++_barangaySequence;
    setState(() {
      _loadingBarangays = true;
      _barangayError = null;
    });
    try {
      final options = await widget.locationRepository.fetchBarangays(cityCode);
      if (!mounted ||
          sequence != _barangaySequence ||
          _selectedCity?.code != cityCode) {
        return;
      }
      setState(() => _barangays = options);
      if (resolveSavedAddress && _address != null) {
        final match = _uniqueLocationMatch(options, _address!.barangay);
        if (match != null) setState(() => _selectedBarangay = match);
      }
    } catch (error) {
      if (mounted && sequence == _barangaySequence) {
        setState(() => _barangayError = error);
      }
    } finally {
      if (mounted && sequence == _barangaySequence) {
        setState(() => _loadingBarangays = false);
      }
    }
  }

  Future<void> _loadPostalCodes({
    String? cityCode,
    String? province,
    String? city,
  }) async {
    final sequence = ++_postalSequence;
    setState(() {
      _loadingPostal = true;
      _postalError = null;
      _postalOptions = const [];
    });
    try {
      final options = await widget.locationRepository.fetchPostalCodes(
        cityCode: cityCode,
        province: province,
        city: city,
      );
      if (!mounted || sequence != _postalSequence) return;
      setState(() => _postalOptions = options);
    } catch (error) {
      if (mounted && sequence == _postalSequence) {
        setState(() => _postalError = error);
      }
    } finally {
      if (mounted && sequence == _postalSequence) {
        setState(() => _loadingPostal = false);
      }
    }
  }

  void _selectProvince(BuyerLocationOption? option) {
    if (option == null || option.code == _selectedProvince?.code) return;
    // Invalidate a postal response that belongs to the previous city before
    // starting any lookups for this new province.
    _postalSequence++;
    setState(() {
      _selectedProvince = option;
      _province.text = option.name;
      _selectedCity = null;
      _selectedBarangay = null;
      _cities = const [];
      _barangays = const [];
      _city.text = '';
      _barangay.text = '';
      _postalOptions = const [];
      _loadingPostal = false;
      _postal.text = '';
      _postalError = null;
    });
    _clearFieldErrors(['province', 'city', 'barangay', 'postal', 'city_code']);
    unawaited(_loadCities(option.code));
  }

  void _selectCity(BuyerLocationOption? option) {
    if (option == null || option.code == _selectedCity?.code) return;
    setState(() {
      _selectedCity = option;
      _city.text = option.name;
      _selectedBarangay = null;
      _barangays = const [];
      _barangay.text = '';
      _postalOptions = const [];
      _postal.text = '';
      _postalError = null;
    });
    _clearFieldErrors(['city', 'barangay', 'postal', 'city_code']);
    unawaited(_loadBarangays(option.code));
    unawaited(
      _loadPostalCodes(
        cityCode: option.code,
        province: _province.text,
        city: option.name,
      ),
    );
  }

  void _selectBarangay(BuyerLocationOption? option) {
    if (option == null) return;
    setState(() {
      _selectedBarangay = option;
      _barangay.text = option.name;
    });
    _clearFieldErrors(['barangay']);
  }

  String? _validateLocation(
    String field,
    String value,
    BuyerLocationOption? selected,
  ) {
    if (value.trim().isEmpty) return 'Required';
    final original = _address;
    final existingValue = switch (field) {
      'province' => original?.province,
      'city' => original?.city,
      _ => original?.barangay,
    };
    if (selected == null && value.trim() != existingValue) {
      return 'Choose a location from the list.';
    }
    if (value.trim().length > 120) return 'Use 120 characters or fewer.';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _generalError = null);
    if (!_formKey.currentState!.validate() || _submitting) return;

    setState(() {
      _submitting = true;
      _fieldErrors = {};
    });
    try {
      if (_address == null) {
        await widget.controller.createAddress(
          BuyerAddressCreate(
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            province: _province.text.trim(),
            city: _city.text.trim(),
            barangay: _barangay.text.trim(),
            postal: _postal.text.trim(),
            street: _street.text.trim(),
            label: _label,
            cityCode: _selectedCity?.code,
          ),
        );
      } else {
        final changes = _buildPatch(_address!);
        if (changes.isEmpty) {
          if (mounted) Navigator.of(context).pop(false);
          return;
        }
        await widget.controller.updateAddress(
          addressId: _address!.id,
          changes: BuyerAddressPatch(changes),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      if (error is ApiHttpException && error.statusCode == 422) {
        setState(() {
          _fieldErrors = _mapValidationErrors(error.validationErrors);
          _generalError = _fieldErrors.isEmpty
              ? buyerAddressErrorMessage(error)
              : null;
        });
      } else {
        setState(() => _generalError = buyerAddressErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Map<String, Object?> _buildPatch(BuyerAddress original) {
    final values = <String, String>{
      'name': _name.text.trim(),
      'phone': _phone.text.trim(),
      'province': _province.text.trim(),
      'city': _city.text.trim(),
      'barangay': _barangay.text.trim(),
      'postal': _postal.text.trim(),
      'street': _street.text.trim(),
      'label': _label,
    };
    final before = <String, String>{
      'name': original.name,
      'phone': original.phone,
      'province': original.province,
      'city': original.city,
      'barangay': original.barangay,
      'postal': original.postal,
      'street': original.street,
      'label': original.label,
    };
    final changes = <String, Object?>{
      for (final entry in values.entries)
        if (entry.value != before[entry.key]) entry.key: entry.value,
    };
    final locationChanged =
        values['province'] != before['province'] ||
        values['city'] != before['city'];
    if (locationChanged && _selectedCity != null) {
      changes['city_code'] = _selectedCity!.code;
    }
    return changes;
  }

  Map<String, String> _mapValidationErrors(Map<String, List<String>> errors) {
    final mapped = <String, String>{};
    for (final entry in errors.entries) {
      final field = switch (entry.key) {
        'contact_number' => 'phone',
        'city_code' => 'city',
        _ => entry.key,
      };
      if ({
            'name',
            'phone',
            'province',
            'city',
            'barangay',
            'postal',
            'street',
            'label',
          }.contains(field) &&
          entry.value.isNotEmpty) {
        mapped[field] = entry.value.first;
      }
    }
    return mapped;
  }

  void _clearFieldErrors(Iterable<String> keys) {
    if (_fieldErrors.isEmpty) return;
    setState(() {
      for (final key in keys) {
        _fieldErrors.remove(key);
      }
    });
  }

  Future<void> _confirmDiscard() async {
    if (!_isDirty || _submitting) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard address changes?'),
        content: const Text('Your unsaved address details will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final address = _address;
    return PopScope<bool>(
      canPop: !_isDirty && !_submitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_submitting) unawaited(_confirmDiscard());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _confirmDiscard,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(_isEditing ? 'Edit address' : 'Add address'),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              key: const ValueKey('buyer-address-form-scroll'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  _isEditing
                      ? 'Update your saved delivery details.'
                      : 'Save a delivery address for your Bearly account.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _textField(
                  keyName: 'buyer-address-name',
                  controller: _name,
                  label: 'Recipient full name',
                  serverField: 'name',
                  validator: (value) => _requiredMax(value, 160),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                _textField(
                  keyName: 'buyer-address-phone',
                  controller: _phone,
                  label: 'Contact number',
                  serverField: 'phone',
                  validator: _validatePhone,
                  keyboardType: TextInputType.phone,
                  maxLength: 30,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const ValueKey('buyer-address-label'),
                  initialValue: _label,
                  decoration: InputDecoration(
                    labelText: 'Address label',
                    errorText: _fieldErrors['label'],
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Home', child: Text('Home')),
                    DropdownMenuItem(value: 'Work', child: Text('Work')),
                  ],
                  onChanged: _submitting
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _label = value);
                          _clearFieldErrors(['label']);
                        },
                ),
                const SizedBox(height: 22),
                Text(
                  'Philippine location',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                _locationDropdown(
                  keyName: 'buyer-address-province',
                  label: 'Province',
                  options: _provinces,
                  selected: _selectedProvince,
                  loading: _loadingProvinces,
                  error: _provinceError,
                  enabled: !_submitting,
                  serverError: _fieldErrors['province'],
                  savedValue: _isEditing && _selectedProvince == null
                      ? _address!.province
                      : null,
                  onChanged: _selectProvince,
                  onRetry: () => _loadProvinces(
                    resolveSavedAddress:
                        _isEditing && _selectedProvince == null,
                  ),
                ),
                const SizedBox(height: 12),
                _locationDropdown(
                  keyName: 'buyer-address-city',
                  label: 'City or municipality',
                  options: _cities,
                  selected: _selectedCity,
                  loading: _loadingCities,
                  error: _cityError,
                  enabled: !_submitting && _selectedProvince != null,
                  serverError: _fieldErrors['city'],
                  savedValue: _isEditing && _selectedCity == null
                      ? _address!.city
                      : null,
                  onChanged: _selectCity,
                  onRetry: _selectedProvince == null
                      ? null
                      : () => _loadCities(_selectedProvince!.code),
                ),
                const SizedBox(height: 12),
                _locationDropdown(
                  keyName: 'buyer-address-barangay',
                  label: 'Barangay',
                  options: _barangays,
                  selected: _selectedBarangay,
                  loading: _loadingBarangays,
                  error: _barangayError,
                  enabled: !_submitting && _selectedCity != null,
                  serverError: _fieldErrors['barangay'],
                  savedValue: _isEditing && _selectedBarangay == null
                      ? _address!.barangay
                      : null,
                  onChanged: _selectBarangay,
                  onRetry: _selectedCity == null
                      ? null
                      : () => _loadBarangays(_selectedCity!.code),
                ),
                const SizedBox(height: 12),
                _textField(
                  keyName: 'buyer-address-street',
                  controller: _street,
                  label: 'Street, building, or house details',
                  serverField: 'street',
                  validator: (value) => _requiredMax(value, 180),
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                _textField(
                  keyName: 'buyer-address-postal',
                  controller: _postal,
                  label: 'Postal code',
                  serverField: 'postal',
                  validator: _validatePostal,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  textInputAction: TextInputAction.done,
                ),
                if (_loadingPostal)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                if (_postalOptions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Postal code suggestions',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final option in _postalOptions)
                        ChoiceChip(
                          key: ValueKey('buyer-postal-option-${option.code}'),
                          label: Text(
                            option.area == null || option.area!.isEmpty
                                ? option.code
                                : '${option.area} · ${option.code}',
                          ),
                          selected: _postal.text == option.code,
                          onSelected: _submitting
                              ? null
                              : (_) {
                                  setState(() => _postal.text = option.code);
                                  _clearFieldErrors(['postal']);
                                },
                        ),
                    ],
                  ),
                ],
                if (_postalError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Postal lookup is unavailable. Enter a four-digit code manually.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BearlyColors.muted,
                      ),
                    ),
                  )
                else if (!_loadingPostal &&
                    _selectedCity != null &&
                    _postalOptions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'No postal suggestions for this location. Enter the code manually.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (_generalError != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _generalError!,
                    key: const ValueKey('buyer-address-form-error'),
                    style: const TextStyle(color: BearlyColors.error),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton.icon(
                  key: const ValueKey('buyer-address-submit'),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _submitting
                        ? 'Saving…'
                        : address == null
                        ? 'Save address'
                        : 'Save changes',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _locationDropdown({
    required String keyName,
    required String label,
    required List<BuyerLocationOption> options,
    required BuyerLocationOption? selected,
    required bool loading,
    required Object? error,
    required bool enabled,
    required ValueChanged<BuyerLocationOption?> onChanged,
    required VoidCallback? onRetry,
    String? serverError,
    String? savedValue,
  }) {
    final codeValues = options.map((option) => option.code).toSet();
    final currentCode = selected != null && codeValues.contains(selected.code)
        ? selected.code
        : null;
    final hint = savedValue != null && savedValue.isNotEmpty
        ? 'Saved: $savedValue'
        : options.isEmpty
        ? (loading ? 'Loading locations…' : 'Choose ${label.toLowerCase()}')
        : 'Select $label';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(keyName),
          initialValue: currentCode,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            errorText: serverError,
            suffixIcon: loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          hint: Text(hint),
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option.code,
                child: Text(option.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: enabled && !loading && options.isNotEmpty
              ? (code) => onChanged(
                  options.where((option) => option.code == code).firstOrNull,
                )
              : null,
          validator: (_) {
            final value = switch (label) {
              'Province' => _province.text,
              'City or municipality' => _city.text,
              _ => _barangay.text,
            };
            final current = switch (label) {
              'Province' => _selectedProvince,
              'City or municipality' => _selectedCity,
              _ => _selectedBarangay,
            };
            return _validateLocation(
              label == 'Province'
                  ? 'province'
                  : label == 'City or municipality'
                  ? 'city'
                  : 'barangay',
              value,
              current,
            );
          },
        ),
        if (savedValue != null && savedValue.isNotEmpty && currentCode == null)
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 5),
            child: Text(
              'The saved value is preserved. Choose an available option only if you are changing it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (error != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Could not load ${label.toLowerCase()} options. Your saved value is preserved.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: BearlyColors.error),
                ),
              ),
              if (onRetry != null)
                TextButton(
                  onPressed: enabled ? onRetry : null,
                  child: const Text('Retry'),
                ),
            ],
          ),
        if (error == null && !loading && enabled && options.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 5),
            child: Text(
              'No ${label.toLowerCase()} options were returned.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _textField({
    required String keyName,
    required TextEditingController controller,
    required String label,
    required String serverField,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputAction? textInputAction,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) => TextFormField(
    key: ValueKey(keyName),
    controller: controller,
    enabled: !_submitting,
    decoration: InputDecoration(
      labelText: label,
      errorText: _fieldErrors[serverField],
      counterText: maxLength == null ? null : '',
    ),
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    textInputAction: textInputAction,
    maxLength: maxLength,
    inputFormatters: inputFormatters,
    validator: validator,
    onChanged: (_) => _clearFieldErrors([serverField]),
  );

  String? _requiredMax(String? raw, int maxLength) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return 'Required';
    if (value.length > maxLength) return 'Use $maxLength characters or fewer.';
    return null;
  }

  String? _validatePhone(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return 'Required';
    if (value.length > 30 ||
        !RegExp(r'^\+?[0-9\s\-()]{7,30}$').hasMatch(value)) {
      return 'Enter a valid contact number.';
    }
    return null;
  }

  String? _validatePostal(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return 'Required';
    return RegExp(r'^\d{4}$').hasMatch(value)
        ? null
        : 'Enter a four-digit postal code.';
  }
}

BuyerLocationOption? _uniqueLocationMatch(
  List<BuyerLocationOption> options,
  String savedName,
) {
  final target = _locationNameKey(savedName);
  final exact = options.where(
    (option) =>
        option.name.trim().toLowerCase() == savedName.trim().toLowerCase(),
  );
  if (exact.length == 1) return exact.single;
  final matches = options.where(
    (option) => _locationNameKey(option.name) == target,
  );
  return matches.length == 1 ? matches.single : null;
}

String _locationNameKey(String value) {
  var normalized = value.trim().toLowerCase();
  normalized = normalized.replaceFirst(
    RegExp(r'^(city of|municipality of|municipality)\s+'),
    '',
  );
  normalized = normalized.replaceFirst(RegExp(r'\s+(city|municipality)$'), '');
  return normalized.replaceAll(RegExp(r'\s+'), ' ');
}
