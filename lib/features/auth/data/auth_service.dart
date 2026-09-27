/// Mobile authentication API boundary.
///
/// The current Flutter auth update intentionally keeps network submission
/// disabled until Laravel exposes mobile-safe JSON endpoints (token/session
/// handling, Google mobile OAuth, registration upload, and password reset).
/// Keeping this boundary in place prevents UI code from posting directly to
/// browser-oriented Blade routes.
class AuthService {
  const AuthService();

  bool get apiConnected => false;
}
