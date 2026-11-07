import '../../../core/network/mobile_image_url_policy.dart';

/// Buyer-facing name retained for existing catalog and URL-policy tests.
class BuyerImageUrlPolicy extends MobileImageUrlPolicy {
  const BuyerImageUrlPolicy({required super.allowLocalHttp});

  static const Set<String> approvedDevelopmentHosts =
      MobileImageUrlPolicy.approvedDevelopmentHosts;
}
