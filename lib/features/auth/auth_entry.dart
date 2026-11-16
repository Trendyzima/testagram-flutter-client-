enum AuthEntryMode { signIn, signUp, forgotPassword, verifyEmail, resetPassword }

class AuthEntry {
  const AuthEntry({
    required this.mode,
    required this.isExplicit,
    this.applicationId,
    this.token,
  });

  final AuthEntryMode mode;
  final bool isExplicit;
  final String? applicationId;
  final String? token;

  bool get hasCompleteCallback {
    if (mode == AuthEntryMode.verifyEmail) {
      return applicationId != null &&
          applicationId!.isNotEmpty &&
          token != null &&
          token!.isNotEmpty;
    }
    if (mode == AuthEntryMode.resetPassword) {
      return token != null && token!.isNotEmpty;
    }
    return false;
  }

  factory AuthEntry.fromUri(Uri uri) {
    final query = uri.queryParameters;
    final rawMode = query['mode'];
    final applicationId = query['application_id'];
    final token = query['token'];
    final path = uri.path.toLowerCase();
    final isNativeVerification = applicationId != null && token != null;
    final isNativeReset = token != null && !isNativeVerification;
    final mode = switch (true) {
      isNativeVerification || path.endsWith('/verify-email') =>
        AuthEntryMode.verifyEmail,
      isNativeReset || path.endsWith('/reset-password') =>
        AuthEntryMode.resetPassword,
      _ => switch (rawMode) {
          'signup' || 'sign-up' => AuthEntryMode.signUp,
          'forgot' => AuthEntryMode.forgotPassword,
          'reset' || 'recovery' => AuthEntryMode.resetPassword,
          'verification' => AuthEntryMode.verifyEmail,
          'signin' || 'sign-in' => AuthEntryMode.signIn,
          _ => AuthEntryMode.signIn,
        },
    };
    return AuthEntry(
      mode: mode,
      isExplicit: isNativeVerification ||
          isNativeReset ||
          path.endsWith('/verify-email') ||
          path.endsWith('/reset-password') ||
          const {
            'signup', 'sign-up', 'forgot', 'reset', 'recovery',
            'verification', 'signin', 'sign-in',
          }.contains(rawMode),
      applicationId: applicationId,
      token: token,
    );
  }
}
