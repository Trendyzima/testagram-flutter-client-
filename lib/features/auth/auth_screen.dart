import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import '../../core/app_config.dart';
import 'auth_entry.dart';

enum _Page { signIn, signUp, forgot, verify, reset }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.account,
    required this.onSignedIn,
    this.requireVerification = false,
    this.initialEmail,
  });
  final Account account;
  final VoidCallback onSignedIn;
  final bool requireVerification;
  final String? initialEmail;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _username = TextEditingController(), _email = TextEditingController();
  final _password = TextEditingController(), _confirm = TextEditingController();
  _Page _page = _Page.signIn;
  bool _busy = false, _obscure = true;
  bool _ageConfirmed = false, _termsAccepted = false;
  String? _error, _notice, _recoveryUser, _recoverySecret;

  @override
  void initState() {
    super.initState();
    _email.text = widget.initialEmail ?? '';
    final entry = AuthEntry.fromUri(Uri.base);
    switch (entry.mode) {
      case AuthEntryMode.resetPassword:
        _recoveryUser = entry.userId;
        _recoverySecret = entry.secret;
        _page = _Page.reset;
        if (!entry.hasCompleteCallback) {
          _error = 'This password reset link is incomplete. Request a new reset email.';
        }
      case AuthEntryMode.verifyEmail:
        _page = _Page.verify;
        if (entry.hasCompleteCallback) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _verify(entry.userId!, entry.secret!),
          );
        } else {
          _notice = 'Open the complete verification link from your email, or request another one.';
        }
      case AuthEntryMode.signUp:
        _page = _Page.signUp;
      case AuthEntryMode.forgotPassword:
        _page = _Page.forgot;
      case AuthEntryMode.signIn:
        if (widget.requireVerification) {
          _page = _Page.verify;
          _notice = 'Verify your email address before using Testagram.';
        }
    }
  }

  @override
  void dispose() {
    _name.dispose(); _username.dispose(); _email.dispose(); _password.dispose(); _confirm.dispose(); super.dispose();
  }

  void _go(_Page p) => setState(() { _page = p; _error = null; _notice = null; });

  String? _emailValid(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) {
      return 'Enter your email address.';
    }
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s) ? null : 'Enter a valid email address.';
  }
  String? _passwordValid(String? v) =>
      v == null || v.length < 8 ? 'Use at least 8 characters.' : v.length > 256 ? 'Password is too long.' : null;

  String? _usernameValid(String? value) {
    final username = (value ?? '').trim().replaceFirst(RegExp(r'^@'), '');
    if (username.length < 3 || username.length > 30) {
      return 'Username must be 3–30 characters.';
    }
    return RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)
        ? null
        : 'Use letters, numbers and underscores only.';
  }

  String _friendly(Object e) {
    if (e is AppwriteException) {
      if (e.code == 401) {
        return 'The email or password is incorrect.';
      }
      if (e.code == 409) {
        return 'We could not create this account. Try signing in or use password recovery if you already registered.';
      }
      if (e.code == 429) {
        return 'Too many attempts. Wait and retry.';
      }
      return e.message ?? 'The request failed.';
    }
    final s = e.toString();
    if (s.contains('ClientException') || s.contains('Failed to fetch') ||
        s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'Cannot reach Appwrite. Check your connection, Appwrite endpoint, project Web platform and CORS settings.';
    }
    if (s.contains('TimeoutException')) {
      return 'Request timed out. Check your connection and retry.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _run(Future<void> Function() fn) async {
    if (_busy) {
      return;
    }
    setState(() { _busy = true; _error = null; _notice = null; });
    try { await fn(); } catch (e) { if (mounted) setState(() => _error = _friendly(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _signIn() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    await _run(() async {
      await widget.account.createEmailPasswordSession(
        email: _email.text.trim().toLowerCase(), password: _password.text);
      final user = await widget.account.get();
      if (!user.emailVerification) {
        if (mounted) {
          setState(() {
            _page = _Page.verify;
            _notice = 'Your email is not verified yet. Check your inbox or resend the verification link.';
          });
        }
        return;
      }
      widget.onSignedIn();
    });
  }

  Future<void> _signUp() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (!_ageConfirmed || !_termsAccepted) {
      setState(() => _error = 'You must confirm that you are 18 or older and accept the Terms and Conditions and Privacy Notice.');
      return;
    }
    // Do not create an Appwrite account directly. Registration must pass the
    // Backend identity-approval issuer and canonical account-linking flow.
    // Those controls are not yet available to this client.
    setState(() {
      _error = null;
      _notice = 'Your details have not been submitted and no account has been created. Secure registration is being completed. Please try again later.';
    });
  }

  Future<void> _resend() async => _run(() async {
    await widget.account.createVerification(url: '${AppConfig.authCallbackOrigin}/?mode=verification');
    if (mounted) {
      setState(() => _notice = 'A new verification email has been sent.');
    }
  });

  Future<void> _verify(String userId, String secret) async => _run(() async {
    // Verification links are commonly opened on a different device/browser
    // with no existing Appwrite session. The one-time Appwrite callback is
    // the authority here; do not require account.get() after redeeming it.
    await widget.account.updateVerification(userId: userId, secret: secret);
    if (mounted) {
      setState(() {
        _page = _Page.signIn;
        _notice = 'Email verified successfully. Sign in to continue.';
      });
    }
  });

  Future<void> _forgot() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    await _run(() async {
      try {
        await widget.account.createRecovery(
          email: _email.text.trim().toLowerCase(),
          url: '${AppConfig.authCallbackOrigin}/?mode=recovery');
      } on AppwriteException catch (error) {
        // Appwrite may distinguish an unknown email. Keep the public response
        // identical so the form cannot be used to enumerate registered users.
        if (error.code != 400 && error.code != 404) rethrow;
      }
      if (mounted) {
        setState(() {
          _page = _Page.signIn;
          _notice = 'If the account exists, a password reset link has been sent.';
        });
      }
    });
  }

  Future<void> _reset() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    if (_recoveryUser == null || _recoverySecret == null) {
      setState(() {
        _error = 'Recovery link is incomplete. Request a new reset email.';
      });
      return;
    }
    await _run(() async {
      try {
        await widget.account.updateRecovery(
          userId: _recoveryUser!, secret: _recoverySecret!, password: _password.text);
      } on AppwriteException catch (error) {
        if (error.code == 400 || error.code == 401 || error.code == 404) {
          if (mounted) {
            setState(() => _error = 'This reset link is invalid, expired or already used. Request a new reset email.');
          }
          return;
        }
        rethrow;
      }
      if (mounted) {
        setState(() {
          _page = _Page.signIn;
          _password.clear();
          _confirm.clear();
          _recoveryUser = null;
          _recoverySecret = null;
        _notice = 'Password changed. Sign in with your new password.';
        });
      }
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
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().length < 2 ? 'Enter your name.' : null),
            const SizedBox(height: 14),
            TextFormField(controller: _username, autocorrect: false,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(labelText: 'Username', prefixText: '@', border: OutlineInputBorder()),
              validator: _usernameValid),
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
          if (_page == _Page.signUp) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _ageConfirmed,
              onChanged: _busy ? null : (value) => setState(() => _ageConfirmed = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I confirm that I am 18 years old or above.'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _termsAccepted,
              onChanged: _busy ? null : (value) => setState(() => _termsAccepted = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I accept the Terms and Conditions and Privacy Notice.'),
            ),
            Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
              TextButton(onPressed: _busy ? null : () => _showLegalDocument('Terms and Conditions', _termsText), child: const Text('Read Terms and Conditions')),
              TextButton(onPressed: _busy ? null : () => _showLegalDocument('Privacy Notice', _privacyText), child: const Text('Read Privacy Notice')),
            ]),
            const SizedBox(height: 8),
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
).hasMatch(username) ? null : 'Use letters, numbers and underscores only.';
  }

  Future<void> _showLegalDocument(String title, String body) async {
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: SelectableText(body))),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    ));
  }

  static const _termsText = '''TESTAGRAM TERMS AND CONDITIONS\n\nEffective version: 2026-11-11\n\n1. Eligibility and accounts\nTestagram is intended for people aged 18 or older. You must provide accurate registration information, keep your credentials secure, and be responsible for activity carried out through your account. Do not impersonate another person, create deceptive accounts, or bypass account restrictions.\n\n2. Acceptable use\nDo not use Testagram to threaten, harass, exploit, defraud, stalk, or unlawfully discriminate against people; share illegal content; distribute malware or spam; infringe intellectual property or privacy rights; manipulate engagement; or interfere with platform security. Do not attempt to access another account or private system without authorization.\n\n3. Content and permissions\nYou retain rights you own in content you submit. You grant Testagram the limited, non-exclusive permission needed to host, process, display, distribute, and technically adapt that content to operate the features you choose, including delivery to people and services you direct it to. You must have the rights and permissions needed to submit the content. You remain responsible for it.\n\n4. Safety and moderation\nTestagram may review, label, restrict, remove, or preserve content and may limit or suspend accounts to protect users, comply with law, enforce these terms, investigate abuse, or maintain service security. Where appropriate, we may provide a review or appeal route.\n\n5. Third-party services and availability\nSome features rely on third-party infrastructure and external services. Features may change or be temporarily unavailable. We do not promise uninterrupted access, and you must follow applicable third-party terms when using their services.\n\n6. Security and termination\nYou must not probe, disrupt, reverse engineer, or circumvent platform safeguards except where applicable law permits. You may stop using Testagram at any time. We may restrict access for serious or repeated violations or where required to protect the platform or comply with law.\n\n7. Changes and contact\nWe may update these terms as the service evolves. Material changes will be communicated through an appropriate platform notice. Continued use after the effective date constitutes acceptance only where permitted by applicable law; where renewed consent is required, we will ask for it.\n\nThis is a product-policy draft and must be reviewed by qualified counsel before public launch.''';
  static const _privacyText = '''TESTAGRAM PRIVACY NOTICE\n\nEffective version: 2026-11-11\n\nTestagram uses information you provide, account and device security signals, and information generated when you use the platform to operate accounts, protect users, deliver features, prevent abuse, and improve reliability.\n\nInformation may include your name, username, email address, profile details, content you choose to upload, account activity, device/app diagnostics, and security/audit events. Do not upload identity documents or sensitive personal information unless a specific, secure platform flow requests it.\n\nWe use information to authenticate you, manage your account, deliver content and communications, enforce platform rules, respond to support requests, secure the service, and meet legal obligations. We do not ask for your password by email or public message.\n\nInformation is processed by Testagram systems and service providers acting to provide hosting, authentication, delivery, security, and support. Access is limited according to operational need. We apply safeguards intended to protect information, but no online service can guarantee absolute security.\n\nDepending on applicable law, you may have rights to access, correct, delete, restrict, or object to certain processing, and to raise a complaint with a relevant authority. Retention depends on account status, security needs, legal requirements, and operational records.\n\nBefore public launch, this notice must be completed with the operator's legal identity, contact details, retention periods, international transfer information, and jurisdiction-specific rights and disclosures. Contact the Testagram operator through the official support channel for privacy requests.''';

  String _friendly(Object e) {
    if (e is AppwriteException) {
      if (e.code == 401) {
        return 'The email or password is incorrect.';
      }
      if (e.code == 409) {
        return 'We could not create this account. Try signing in or use password recovery if you already registered.';
      }
      if (e.code == 429) {
        return 'Too many attempts. Wait and retry.';
      }
      return e.message ?? 'The request failed.';
    }
    final s = e.toString();
    if (s.contains('ClientException') || s.contains('Failed to fetch') ||
        s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'Cannot reach Appwrite. Check your connection, Appwrite endpoint, project Web platform and CORS settings.';
    }
    if (s.contains('TimeoutException')) {
      return 'Request timed out. Check your connection and retry.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _run(Future<void> Function() fn) async {
    if (_busy) {
      return;
    }
    setState(() { _busy = true; _error = null; _notice = null; });
    try { await fn(); } catch (e) { if (mounted) setState(() => _error = _friendly(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _signIn() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    await _run(() async {
      await widget.account.createEmailPasswordSession(
        email: _email.text.trim().toLowerCase(), password: _password.text);
      final user = await widget.account.get();
      if (!user.emailVerification) {
        if (mounted) {
          setState(() {
            _page = _Page.verify;
            _notice = 'Your email is not verified yet. Check your inbox or resend the verification link.';
          });
        }
        return;
      }
      widget.onSignedIn();
    });
  }

  Future<void> _signUp() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    await _run(() async {
      final email = _email.text.trim().toLowerCase();
      await widget.account.create(userId: ID.unique(), email: email,
        password: _password.text, name: _name.text.trim());
      await widget.account.createEmailPasswordSession(email: email, password: _password.text);
      if (mounted) {
        setState(() {
          _page = _Page.verify;
          _notice = 'Account created. Sending a verification link to $email.';
        });
      }
      await widget.account.createVerification(url: '${AppConfig.authCallbackOrigin}/?mode=verification');
      if (mounted) {
        setState(() {
          _notice = 'Verification email sent to $email. Open the link before signing in.';
        });
      }
    });
  }

  Future<void> _resend() async => _run(() async {
    await widget.account.createVerification(url: '${AppConfig.authCallbackOrigin}/?mode=verification');
    if (mounted) {
      setState(() => _notice = 'A new verification email has been sent.');
    }
  });

  Future<void> _verify(String userId, String secret) async => _run(() async {
    // Verification links are commonly opened on a different device/browser
    // with no existing Appwrite session. The one-time Appwrite callback is
    // the authority here; do not require account.get() after redeeming it.
    await widget.account.updateVerification(userId: userId, secret: secret);
    if (mounted) {
      setState(() {
        _page = _Page.signIn;
        _notice = 'Email verified successfully. Sign in to continue.';
      });
    }
  });

  Future<void> _forgot() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    await _run(() async {
      try {
        await widget.account.createRecovery(
          email: _email.text.trim().toLowerCase(),
          url: '${AppConfig.authCallbackOrigin}/?mode=recovery');
      } on AppwriteException catch (error) {
        // Appwrite may distinguish an unknown email. Keep the public response
        // identical so the form cannot be used to enumerate registered users.
        if (error.code != 400 && error.code != 404) rethrow;
      }
      if (mounted) {
        setState(() {
          _page = _Page.signIn;
          _notice = 'If the account exists, a password reset link has been sent.';
        });
      }
    });
  }

  Future<void> _reset() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    if (_recoveryUser == null || _recoverySecret == null) {
      setState(() {
        _error = 'Recovery link is incomplete. Request a new reset email.';
      });
      return;
    }
    await _run(() async {
      try {
        await widget.account.updateRecovery(
          userId: _recoveryUser!, secret: _recoverySecret!, password: _password.text);
      } on AppwriteException catch (error) {
        if (error.code == 400 || error.code == 401 || error.code == 404) {
          if (mounted) {
            setState(() => _error = 'This reset link is invalid, expired or already used. Request a new reset email.');
          }
          return;
        }
        rethrow;
      }
      if (mounted) {
        setState(() {
          _page = _Page.signIn;
          _password.clear();
          _confirm.clear();
          _recoveryUser = null;
          _recoverySecret = null;
        _notice = 'Password changed. Sign in with your new password.';
        });
      }
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
