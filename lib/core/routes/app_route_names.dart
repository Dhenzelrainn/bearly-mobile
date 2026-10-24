/// Stable route identifiers shared by feature screens and the route registry.
///
/// Keeping these names separate lets screens navigate without importing the
/// registry that imports those same screens.
class AppRouteNames {
  const AppRouteNames._();

  static const landing = '/';
  static const login = '/login';
  static const logout = '/logout';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const pending = '/application/pending';
  static const buyer = '/buyer';
  static const buyerHome = '/buyer/home';
  static const rider = '/rider';
  static const riderDashboard = '/rider/dashboard';
  static const riderRegister = '/rider/register';
  static const riderPending = '/rider/pending';
  static const riderRequests = '/rider/requests';
  static const riderPickup = '/rider/pickup';
  static const riderTransit = '/rider/transit';
  static const riderComplete = '/rider/complete';
  static const riderEarnings = '/rider/earnings';
  static const riderHistory = '/rider/history';
  static const riderMessages = '/rider/messages';
  static const riderAccount = '/rider/account';
  static const buyerCart = '/buyer/cart';
  static const buyerCheckoutReview = '/buyer/checkout/review';
  static const buyerOrderDetails = '/buyer/orders/details';
  static const buyerProduct = '/buyer/product';
}
