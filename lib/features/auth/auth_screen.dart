import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';

enum _AuthMode { signIn, createAccount, requestRecovery, resetPassword }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.account, required this.onSignedIn});

  final Account account;
  final VoidCallback onSignedIn;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static const _recoveryUrl = 'https://testagram.site/reset-password';

  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordAgain = TextEditingController();

  late final String? _recoveryUserId;
  late final String? _recoverySecret;
  late _AuthMode _mode;
  bool _busy = false;
  bool _ageConfirmed = false;
  bool _termsAccepted = false;
  bool _showPassword = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    final params = Uri.base.queryParameters;
    _recoveryUserId = params['userId'];
    _recoverySecret = params['secret'];
    _mode = (_recoveryUserId?.isNotEmpty == true &&
            _recoverySecret?.isNotEmpty == true)
        ? _AuthMode.resetPassword
        : _AuthMode.signIn;
  }

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _passwordAgain.dispose();
    super.dispose();
  }

  String? _validateDisplayName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'Enter your display name.';
    if (name.length > 80) return 'Display name must be 80 characters or fewer.';
    return null;
  }

  String? _validateUsername(String? value) {
    final username = (value ?? '').trim().replaceFirst(RegExp(r'^@'), '');
    if (username.length < 3 || username.length > 30) return 'Username must be 3–30 characters.';
    if (!RegExp(r'^[a-zA-Z0-9_]+
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Enter your email address.';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address.';
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password.';
    return null;
  }

  String _friendlyError(AppwriteException error, String fallback) {
    switch (error.code) {
      case 400:
        return error.message ?? 'Check the information and try again.';
      case 401:
        return 'Your email or password is incorrect.';
      case 404:
        return 'The account or recovery link could not be found.';
      case 409:
        return 'An account with this email already exists. Try signing in.';
      case 429:
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!
            : fallback;
    }
  }

  Future<void> _signIn() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.account.createEmailPasswordSession(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) widget.onSignedIn();
    } on AppwriteException catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error, 'Sign-in failed.'));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not connect to Testagram. Check your internet connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showRegistrationStatus() {
    if (_busy || !_formKey.currentState!.validate()) return;
    if (!_ageConfirmed || !_termsAccepted) {
      setState(() => _error = 'Confirm that you meet the age requirement and accept the Terms and Privacy Policy.');
      return;
    }
    setState(() {
      _error = 'Secure account registration is being connected to Testagram identity approval and email verification. No account has been created yet. Please try again when registration is enabled.';
      _notice = null;
    });
  }

  Future<void> _requestRecovery() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.account.createRecovery(
        email: _email.text.trim(),
        url: _recoveryUrl,
      );
      if (mounted) {
        setState(() => _notice =
            'If an account exists for this email, a password-reset link has been sent. Check your inbox and spam folder.');
      }
    } on AppwriteException catch (error) {
      if (mounted) {
        setState(() => _error =
            _friendlyError(error, 'We could not send the recovery email. Try again.'));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not send the recovery email. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    if (_password.text != _passwordAgain.text) {
      setState(() => _error = 'The passwords do not match.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Use at least 8 characters for your new password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.account.updateRecovery(
        userId: _recoveryUserId!,
        secret: _recoverySecret!,
        password: _password.text,
      );
      if (mounted) {
        setState(() {
          _mode = _AuthMode.signIn;
          _password.clear();
          _passwordAgain.clear();
          _notice = 'Your password has been changed. You can now sign in.';
        });
      }
    } on AppwriteException catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyError(
            error, 'This reset link is invalid or expired. Request a new one.'));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not reset your password. Request a new recovery link and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changeMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _notice = null;
      _password.clear();
      _passwordAgain.clear();
      _displayName.clear();
      _username.clear();
      _ageConfirmed = false;
      _termsAccepted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReset = _mode == _AuthMode.resetPassword;
    final isRecovery = _mode == _AuthMode.requestRecovery;
    final isRegistration = _mode == _AuthMode.createAccount;
    final title = isReset
        ? 'Choose a new password'
        : isRecovery
            ? 'Reset your password'
            : isRegistration
                ? 'Create your account'
                : 'Welcome back';
    final subtitle = isReset
        ? 'Create a new password for your Testagram account.'
        : isRecovery
            ? 'Enter the email address linked to your account. We will send you a secure reset link.'
            : isRegistration
                ? 'Join Testagram. Your account will require secure identity approval and email verification.'
                : 'Sign in to your Testagram account.';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.hub_rounded,
                        color: Color(0xFF18A957), size: 54),
                    const SizedBox(height: 18),
                    Text(title, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(subtitle),
                    const SizedBox(height: 28),
                    if (!isReset) ...[
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction:
                            isRecovery ? TextInputAction.done : TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        validator: _validateEmail,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        onFieldSubmitted: (_) {
                          if (isRecovery) _requestRecovery();
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (!isRecovery) ...[
                      TextFormField(
                        controller: _password,
                        obscureText: !_showPassword,
                        textInputAction: isReset
                            ? TextInputAction.next
                            : TextInputAction.done,
                        autofillHints: isReset
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                        validator: (value) {\n                          final error = _validatePassword(value);\n                          if (error != null) return error;\n                          if ((isReset || isRegistration) && (value ?? '').length < 8) return 'Use at least 8 characters.';\n                          return null;\n                        },
                        decoration: InputDecoration(
                          labelText: isReset ? 'New password' : 'Password',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _showPassword ? 'Hide password' : 'Show password',
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(_showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                          ),
                        ),
                        onFieldSubmitted: (_) {
                          if (!isReset) _signIn();
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (isReset)
                      TextFormField(
                        controller: _passwordAgain,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if ((value ?? '').isEmpty) {
                            return 'Confirm your new password.';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Confirm new password',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_reset_outlined),
                        ),
                        onFieldSubmitted: (_) => _resetPassword(),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _MessageBanner(message: _error!, isError: true),
                    ],
                    if (_notice != null) ...[
                      const SizedBox(height: 12),
                      _MessageBanner(message: _notice!, isError: false),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : isReset
                              ? _resetPassword
                              : isRecovery
                                  ? _requestRecovery
                                  : _signIn,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isReset
                              ? 'Save new password'
                              : isRecovery
                                  ? 'Send recovery email'
                                  : 'Sign in'),
                    ),
                    const SizedBox(height: 12),
                    if (_mode == _AuthMode.signIn)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _changeMode(_AuthMode.requestRecovery),
                        child: const Text('Forgot password?'),
                      )
                    else if (!isReset)
                      TextButton(
                        onPressed:
                            _busy ? null : () => _changeMode(_AuthMode.signIn),
                        child: Text(isRegistration ? 'Already have an account? Sign in' : 'Back to sign in'),
                      ),
                    if (_mode == _AuthMode.signIn || isRegistration) ...[
                      const SizedBox(height: 12),
                      const Text(
                        isRegistration\n                            ? 'Your details are not submitted until secure identity approval, email verification and profile linking are available.'\n                            : 'Account access is verified by Appwrite and the Testagram Backend. Accounts must be linked to a canonical Testagram profile.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = isError ? colors.error : colors.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: TextStyle(color: isError ? colors.error : colors.onSurface),
      ),
    );
  }
}
).hasMatch(username)) return 'Use only letters, numbers and underscores.';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Enter your email address.';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address.';
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password.';
    return null;
  }

  String _friendlyError(AppwriteException error, String fallback) {
    switch (error.code) {
      case 400:
        return error.message ?? 'Check the information and try again.';
      case 401:
        return 'Your email or password is incorrect.';
      case 404:
        return 'The account or recovery link could not be found.';
      case 409:
        return 'An account with this email already exists. Try signing in.';
      case 429:
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!
            : fallback;
    }
  }

  Future<void> _signIn() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.account.createEmailPasswordSession(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) widget.onSignedIn();
    } on AppwriteException catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error, 'Sign-in failed.'));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not connect to Testagram. Check your internet connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestRecovery() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.account.createRecovery(
        email: _email.text.trim(),
        url: _recoveryUrl,
      );
      if (mounted) {
        setState(() => _notice =
            'If an account exists for this email, a password-reset link has been sent. Check your inbox and spam folder.');
      }
    } on AppwriteException catch (error) {
      if (mounted) {
        setState(() => _error =
            _friendlyError(error, 'We could not send the recovery email. Try again.'));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not send the recovery email. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    if (_password.text != _passwordAgain.text) {
      setState(() => _error = 'The passwords do not match.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Use at least 8 characters for your new password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.account.updateRecovery(
        userId: _recoveryUserId!,
        secret: _recoverySecret!,
        password: _password.text,
      );
      if (mounted) {
        setState(() {
          _mode = _AuthMode.signIn;
          _password.clear();
          _passwordAgain.clear();
          _notice = 'Your password has been changed. You can now sign in.';
        });
      }
    } on AppwriteException catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyError(
            error, 'This reset link is invalid or expired. Request a new one.'));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not reset your password. Request a new recovery link and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changeMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _notice = null;
      _password.clear();
      _passwordAgain.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReset = _mode == _AuthMode.resetPassword;
    final isRecovery = _mode == _AuthMode.requestRecovery;
    final title = isReset
        ? 'Choose a new password'
        : isRecovery
            ? 'Reset your password'
            : 'Welcome back';
    final subtitle = isReset
        ? 'Create a new password for your Testagram account.'
        : isRecovery
            ? 'Enter the email address linked to your account. We will send you a secure reset link.'
            : 'Sign in to your Testagram account.';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.hub_rounded,
                        color: Color(0xFF18A957), size: 54),
                    const SizedBox(height: 18),
                    Text(title, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(subtitle),
                    const SizedBox(height: 28),
                    if (!isReset) ...[
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction:
                            isRecovery ? TextInputAction.done : TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        validator: _validateEmail,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        onFieldSubmitted: (_) {
                          if (isRecovery) _requestRecovery();
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (!isRecovery) ...[
                      TextFormField(
                        controller: _password,
                        obscureText: !_showPassword,
                        textInputAction: isReset
                            ? TextInputAction.next
                            : TextInputAction.done,
                        autofillHints: isReset
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                        validator: _validatePassword,
                        decoration: InputDecoration(
                          labelText: isReset ? 'New password' : 'Password',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _showPassword ? 'Hide password' : 'Show password',
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(_showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                          ),
                        ),
                        onFieldSubmitted: (_) {
                          if (!isReset) _signIn();
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (isReset)
                      TextFormField(
                        controller: _passwordAgain,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if ((value ?? '').isEmpty) {
                            return 'Confirm your new password.';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Confirm new password',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_reset_outlined),
                        ),
                        onFieldSubmitted: (_) => _resetPassword(),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _MessageBanner(message: _error!, isError: true),
                    ],
                    if (_notice != null) ...[
                      const SizedBox(height: 12),
                      _MessageBanner(message: _notice!, isError: false),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : isReset
                              ? _resetPassword
                              : isRecovery
                                  ? _requestRecovery
                                  : _signIn,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isReset
                              ? 'Save new password'
                              : isRecovery
                                  ? 'Send recovery email'
                                  : 'Sign in'),
                    ),
                    const SizedBox(height: 12),
                    if (_mode == _AuthMode.signIn)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _changeMode(_AuthMode.requestRecovery),
                        child: const Text('Forgot password?'),
                      )
                    else if (!isReset)
                      TextButton(
                        onPressed:
                            _busy ? null : () => _changeMode(_AuthMode.signIn),
                        child: const Text('Back to sign in'),
                      ),
                    if (_mode == _AuthMode.signIn) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Account access is verified by Appwrite and the Testagram Backend. Accounts must be linked to a canonical Testagram profile.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = isError ? colors.error : colors.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: TextStyle(color: isError ? colors.error : colors.onSurface),
      ),
    );
  }
}
