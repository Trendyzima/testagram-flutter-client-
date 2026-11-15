import 'package:flutter/material.dart';

import '../../core/native_auth_session.dart';

enum _NativeAuthPage { signIn, forgotPassword, resetPassword }

class NativeAuthScreen extends StatefulWidget {
  const NativeAuthScreen({
    super.key,
    required this.session,
    required this.onSignedIn,
  });

  final NativeAuthSession session;
  final Future<void> Function() onSignedIn;

  @override
  State<NativeAuthScreen> createState() => _NativeAuthScreenState();
}

class _NativeAuthScreenState extends State<NativeAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  _NativeAuthPage _page = _NativeAuthPage.signIn;
  String _resetToken = '';
  String? _error;
  String? _notice;
  bool _busy = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final uri = Uri.base;
    final token = uri.queryParameters['token'] ?? '';
    if (uri.path.endsWith('/reset-password') && token.isNotEmpty) {
      _resetToken = token;
      _page = _NativeAuthPage.resetPassword;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String? _emailValidator(String? value) {
    final email = (value ?? '').trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.length < 12) return 'Use at least 12 characters.';
    if (value.length > 128) return 'Password must be 128 characters or fewer.';
    return null;
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      switch (_page) {
        case _NativeAuthPage.signIn:
          try {
            await widget.session.signIn(
              email: _email.text,
              password: _password.text,
            );
          } on NativeAuthException catch (error) {
            if (error.code == 'PASSWORD_RESET_REQUIRED') {
              setState(() {
                _page = _NativeAuthPage.forgotPassword;
                _notice = 'This migrated account needs a new Testagram password. Request a secure reset link.';
              });
              return;
            }
            rethrow;
          }
          await widget.onSignedIn();
          break;
        case _NativeAuthPage.forgotPassword:
          await widget.session.requestPasswordReset(_email.text);
          setState(() {
            _notice = 'If this address belongs to an eligible Testagram account, password-reset instructions have been sent.';
            _page = _NativeAuthPage.signIn;
          });
          break;
        case _NativeAuthPage.resetPassword:
          if (_resetToken.isEmpty) {
            throw const NativeAuthException('This reset link is incomplete. Request a new one.');
          }
          if (_newPassword.text != _confirmPassword.text) {
            throw const NativeAuthException('The passwords do not match.');
          }
          await widget.session.resetPassword(
            token: _resetToken,
            newPassword: _newPassword.text,
          );
          _password.clear();
          _newPassword.clear();
          _confirmPassword.clear();
          setState(() {
            _page = _NativeAuthPage.signIn;
            _notice = 'Password updated. Sign in with your new password.';
          });
          break;
      }
    } on NativeAuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Testagram could not complete the request. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _switchPage(_NativeAuthPage page) {
    if (_busy) return;
    setState(() {
      _page = page;
      _error = null;
      _notice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_page) {
      _NativeAuthPage.signIn => 'Sign in to Testagram',
      _NativeAuthPage.forgotPassword => 'Reset your password',
      _NativeAuthPage.resetPassword => 'Choose a new password',
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hub_rounded, size: 52),
                    const SizedBox(height: 16),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    const Text(
                      'Secure sign-in is managed by Testagram on its own backend.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_notice != null) ...[
                      Text(_notice!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                    ],
                    if (_error != null) ...[
                      Text(_error!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                    ],
                    if (_page != _NativeAuthPage.resetPassword) ...[
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email address'),
                        validator: _emailValidator,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_page == _NativeAuthPage.signIn) ...[
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          ),
                        ),
                        validator: _passwordValidator,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : () => _switchPage(_NativeAuthPage.forgotPassword),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    ],
                    if (_page == _NativeAuthPage.resetPassword) ...[
                      TextFormField(
                        controller: _newPassword,
                        obscureText: _obscure,
                        decoration: const InputDecoration(labelText: 'New password'),
                        validator: _passwordValidator,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPassword,
                        obscureText: _obscure,
                        decoration: const InputDecoration(labelText: 'Confirm new password'),
                        validator: (value) => value == _newPassword.text ? null : 'Passwords do not match.',
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(switch (_page) {
                              _NativeAuthPage.signIn => 'Sign in',
                              _NativeAuthPage.forgotPassword => 'Send reset link',
                              _NativeAuthPage.resetPassword => 'Update password',
                            }),
                    ),
                    if (_page != _NativeAuthPage.signIn)
                      TextButton(
                        onPressed: _busy ? null : () => _switchPage(_NativeAuthPage.signIn),
                        child: const Text('Back to sign in'),
                      ),
                    const SizedBox(height: 18),
                    const Text(
                      'New accounts are provisioned only after the identity review and independent approval process.',
                      textAlign: TextAlign.center,
                    ),
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
