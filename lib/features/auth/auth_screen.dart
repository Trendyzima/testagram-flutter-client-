import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import '../../core/app_config.dart';

enum _Page { signIn, signUp, forgot, verify, reset }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.account, required this.onSignedIn});
  final Account account;
  final VoidCallback onSignedIn;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _email = TextEditingController();
  final _password = TextEditingController(), _confirm = TextEditingController();
  _Page _page = _Page.signIn;
  bool _busy = false, _obscure = true;
  String? _error, _notice, _recoveryUser, _recoverySecret;

  @override
  void initState() {
    super.initState();
    final q = Uri.base.queryParameters;
    if (q['mode'] == 'recovery' && q['userId'] != null && q['secret'] != null) {
      _recoveryUser = q['userId']; _recoverySecret = q['secret']; _page = _Page.reset;
    } else if (q['mode'] == 'verification' && q['userId'] != null && q['secret'] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify(q['userId']!, q['secret']!));
    }
  }

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _password.dispose(); _confirm.dispose(); super.dispose();
  }

  void _go(_Page p) => setState(() { _page = p; _error = null; _notice = null; });

  String? _emailValid(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter your email address.';
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s) ? null : 'Enter a valid email address.';
  }
  String? _passwordValid(String? v) =>
      v == null || v.length < 8 ? 'Use at least 8 characters.' : null;

  String _friendly(Object e) {
    if (e is AppwriteException) {
      if (e.code == 401) return 'The email or password is incorrect.';
      if (e.code == 409) return 'An account already exists. Sign in instead.';
      if (e.code == 429) return 'Too many attempts. Wait and retry.';
      return e.message ?? 'The request failed.';
    }
    final s = e.toString();
    if (s.contains('ClientException') || s.contains('Failed to fetch') ||
        s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'Cannot reach Appwrite. Check your connection, Appwrite endpoint, project Web platform and CORS settings.';
    }
    if (s.contains('TimeoutException')) return 'Request timed out. Check your connection and retry.';
    return 'Something went wrong. Please try again.';
  }

  Future<void> _run(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; _notice = null; });
    try { await fn(); } catch (e) { if (mounted) setState(() => _error = _friendly(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _signIn() async {
    if (!_form.currentState!.validate()) return;
    await _run(() async {
      await widget.account.createEmailPasswordSession(
        email: _email.text.trim().toLowerCase(), password: _password.text);
      widget.onSignedIn();
    });
  }

  Future<void> _signUp() async {
    if (!_form.currentState!.validate()) return;
    await _run(() async {
      final email = _email.text.trim().toLowerCase();
      await widget.account.create(userId: ID.unique(), email: email,
        password: _password.text, name: _name.text.trim());
      await widget.account.createEmailPasswordSession(email: email, password: _password.text);
      if (mounted) setState(() {
        _page = _Page.verify;
        _notice = 'Account created. Sending a verification link to ' + email + '.';
      });
      await widget.account.createVerification(url: AppConfig.siteUrl + '/?mode=verification');
      if (mounted) setState(() {
        _notice = 'Verification email sent to ' + email + '. Open the link before signing in.';
      });
    });
  }

  Future<void> _resend() async => _run(() async {
    await widget.account.createVerification(url: AppConfig.siteUrl + '/?mode=verification');
    if (mounted) setState(() => _notice = 'A new verification email has been sent.');
  });

  Future<void> _verify(String userId, String secret) async => _run(() async {
    await widget.account.updateVerification(userId: userId, secret: secret);
    if (mounted) setState(() { _page = _Page.signIn; _notice = 'Email verified. Sign in to continue.'; });
  });

  Future<void> _forgot() async {
    if (!_form.currentState!.validate()) return;
    await _run(() async {
      await widget.account.createRecovery(
        email: _email.text.trim().toLowerCase(),
        url: AppConfig.siteUrl + '/?mode=recovery');
      if (mounted) setState(() {
        _page = _Page.signIn;
        _notice = 'If the account exists, a password reset link has been sent.';
      });
    });
  }

  Future<void> _reset() async {
    if (!_form.currentState!.validate()) return;
    if (_recoveryUser == null || _recoverySecret == null) {
      setState(() => _error = 'Recovery link is incomplete. Request a new reset email.'); return;
    }
    await _run(() async {
      await widget.account.updateRecovery(
        userId: _recoveryUser!, secret: _recoverySecret!, password: _password.text);
      if (mounted) setState(() {
        _page = _Page.signIn; _password.clear(); _confirm.clear();
        _recoveryUser = null; _recoverySecret = null;
        _notice = 'Password changed. Sign in with your new password.';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_page) {
      _Page.signIn => 'Welcome back', _Page.signUp => 'Create your account',
      _Page.forgot => 'Reset your password', _Page.verify => 'Verify your email',
      _Page.reset => 'Choose a new password',
    };
    final subtitle = switch (_page) {
      _Page.signIn => 'Sign in to your Testagram account.',
      _Page.signUp => 'Join Testagram with your email address.',
      _Page.forgot => 'We will send a secure password reset link.',
      _Page.verify => 'Check your inbox and verify your email address.',
      _Page.reset => 'Choose a strong password you have not used before.',
    };
    return Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24), child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.hub_rounded, color: Color(0xFF18A957), size: 58),
          const SizedBox(height: 20), Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8), Text(subtitle), const SizedBox(height: 28),
          if (_page == _Page.signUp) ...[
            TextFormField(controller: _name, textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().length < 2 ? 'Enter your name.' : null),
            const SizedBox(height: 14),
          ],
          if ({_Page.signIn, _Page.signUp, _Page.forgot}.contains(_page))
            TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
              autocorrect: false, autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              validator: _emailValid),
          if ({_Page.signIn, _Page.signUp, _Page.reset}.contains(_page)) ...[
            const SizedBox(height: 14),
            TextFormField(controller: _password, obscureText: _obscure,
              autofillHints: _page == _Page.signIn ? const [AutofillHints.password] : const [AutofillHints.newPassword],
              decoration: InputDecoration(labelText: _page == _Page.reset ? 'New password' : 'Password',
                border: const OutlineInputBorder(), suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
              validator: _passwordValid,
              onFieldSubmitted: (_) { if (_page == _Page.signIn) _signIn(); if (_page == _Page.signUp) _signUp(); }),
          ],
          if (_page == _Page.signUp || _page == _Page.reset) ...[
            const SizedBox(height: 14),
            TextFormField(controller: _confirm, obscureText: _obscure,
              decoration: const InputDecoration(labelText: 'Confirm password', border: OutlineInputBorder()),
              validator: (v) => v != _password.text ? 'Passwords do not match.' : null),
          ],
          if (_error != null) ...[const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
          if (_notice != null) ...[const SizedBox(height: 14),
            Text(_notice!, style: const TextStyle(color: Color(0xFF168A4B)))],
          const SizedBox(height: 20),
          if (_page == _Page.signIn) FilledButton(onPressed: _busy ? null : _signIn,
            child: _busy ? const CircularProgressIndicator() : const Text('Sign in')),
          if (_page == _Page.signUp) FilledButton(onPressed: _busy ? null : _signUp,
            child: _busy ? const CircularProgressIndicator() : const Text('Create account')),
          if (_page == _Page.forgot) FilledButton(onPressed: _busy ? null : _forgot,
            child: _busy ? const CircularProgressIndicator() : const Text('Send reset link')),
          if (_page == _Page.reset) FilledButton(onPressed: _busy ? null : _reset,
            child: _busy ? const CircularProgressIndicator() : const Text('Update password')),
          if (_page == _Page.verify) OutlinedButton(onPressed: _busy ? null : _resend,
            child: const Text('Resend verification email')),
          const SizedBox(height: 12),
          if (_page == _Page.signIn) ...[
            TextButton(onPressed: _busy ? null : () => _go(_Page.forgot), child: const Text('Forgot password?')),
            TextButton(onPressed: _busy ? null : () => _go(_Page.signUp), child: const Text('Create a new account')),
          ] else if (_page != _Page.verify)
            TextButton(onPressed: _busy ? null : () => _go(_Page.signIn), child: const Text('Back to sign in'))
          else
            TextButton(onPressed: _busy ? null : () => _go(_Page.signIn), child: const Text('Back to sign in')),
          const SizedBox(height: 12),
          const Text('Appwrite authenticates accounts. Testagram Backend remains responsible for canonical profile linking and product authorization.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
        ])),
      ),
    ))));
  }
}
