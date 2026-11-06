/// Region fields added to the mobile registration address contract.
///
/// A selected PSGC code is passed through unchanged. Manual address entry
/// supplies only the region name and leaves the optional code absent.
class RegistrationRegionFields {
  const RegistrationRegionFields({required this.region, this.regionCode});

  final String region;
  final String? regionCode;

  static final RegExp _regionCodePattern = RegExp(r'^\d{10}$');

  static String? validateRegion(String? value) {
    return (value ?? '').trim().isEmpty ? 'Enter your region.' : null;
  }

  static String? validateRegionCode(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty || _regionCodePattern.hasMatch(code)) return null;
    return 'Select a valid 10-digit PSGC region code.';
  }

  Map<String, Object?> toJson() {
    final normalizedRegion = region.trim();
    if (validateRegion(normalizedRegion) != null) {
      throw ArgumentError.value(region, 'region', 'A region is required.');
    }

    final normalizedCode = regionCode?.trim() ?? '';
    if (validateRegionCode(normalizedCode) != null) {
      throw ArgumentError.value(
        regionCode,
        'regionCode',
        'A PSGC region code must contain exactly 10 digits.',
      );
    }

    return {
      'region': normalizedRegion,
      if (normalizedCode.isNotEmpty) 'region_code': normalizedCode,
    };
  }
}
