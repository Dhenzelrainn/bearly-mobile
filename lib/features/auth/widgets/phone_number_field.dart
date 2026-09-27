import 'dart:math' as math;

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../../core/theme/bearly_theme.dart';

class PhoneNumberField extends StatelessWidget {
  const PhoneNumberField({
    super.key,
    required this.controller,
    required this.countryCode,
    required this.onCountryChanged,
    required this.riderMode,
  });

  final TextEditingController controller;
  final String countryCode;
  final ValueChanged<String> onCountryChanged;
  final bool riderMode;

  Country get _country =>
      CountryService().findByCode(riderMode ? 'PH' : countryCode) ??
      Country.parse('PH');

  String? _validator(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Enter your mobile number.';

    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return 'Enter a valid mobile number.';

    try {
      final iso = IsoCode.fromJson(_country.countryCode);
      final parsed = PhoneNumber.parse(
        digits,
        callerCountry: iso,
      );

      if (!parsed.isValid(type: PhoneNumberType.mobile)) {
        return riderMode
            ? 'Enter a valid Philippine mobile number.'
            : 'Enter a valid mobile number for ${_country.name}.';
      }
    } catch (_) {
      return riderMode
          ? 'Enter a valid Philippine mobile number.'
          : 'Enter a valid mobile number for ${_country.name}.';
    }

    return null;
  }

  void _showCountryPicker(BuildContext context) {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      showSearch: true,
      showDragHandle: true,
      useSafeArea: true,
      favorite: const ['PH'],
      countryListTheme: CountryListThemeData(
        backgroundColor: BearlyColors.cream50,
        bottomSheetHeight: MediaQuery.sizeOf(context).height * .78,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        inputDecoration: const InputDecoration(
          hintText: 'Search country',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
      onSelect: (country) {
        controller.clear();
        onCountryChanged(country.countryCode);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final country = _country;
    final maxNationalDigits = math.max(4, 15 - country.phoneCode.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: riderMode ? 98 : 136,
              child: InkWell(
                onTap: riderMode ? null : () => _showCountryPicker(context),
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: riderMode ? 'Country' : 'Country code',
                    enabled: true,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(country.flagEmoji),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '+${country.phoneCode}',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      if (!riderMode)
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                maxLength: maxNationalDigits,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Mobile number',
                  hintText: country.example.isNotEmpty
                      ? country.example
                      : 'Mobile number',
                  counterText: '',
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                validator: _validator,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          riderMode
              ? 'Rider accounts use a Philippine (+63) mobile number.'
              : '${country.name} · +${country.phoneCode}. Enter the national mobile number only.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
