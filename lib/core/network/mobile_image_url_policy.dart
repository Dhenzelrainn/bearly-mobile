/// Limits Mobile product images to secure public URLs, with the existing
/// local HTTP exceptions used by Flutter debug builds.
class MobileImageUrlPolicy {
  const MobileImageUrlPolicy({required this.allowLocalHttp});

  static const Set<String> approvedDevelopmentHosts = {
    '127.0.0.1',
    'localhost',
    '10.0.2.2',
  };

  final bool allowLocalHttp;

  String? normalize(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;

    final candidate = value.trim();
    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return null;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'https') return candidate;

    if (scheme != 'http' ||
        !allowLocalHttp ||
        !approvedDevelopmentHosts.contains(uri.host.toLowerCase())) {
      return null;
    }

    return candidate;
  }
}
