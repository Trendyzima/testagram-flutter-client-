
import 'dart:convert';
import 'dart:math';

import 'package:appwrite/appwrite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/app_config.dart';
import '../../core/backend_api.dart';
import 'auth_entry.dart';
import 'identity_verification_client.dart';

enum _Page { signIn, signUp, forgot, verify, reset, identity }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.account,
    required this.onSignedIn,
    this.requireVerification = false,
    this.requireIdentityReview = false,
    this.initialEmail,
    this.enableIdentityRegistration = false,
  });
  final Account account;
  final VoidCallback onSignedIn;
  final bool requireVerification;
  final bool requireIdentityReview;
  final String? initialEmail;
  final bool enableIdentityRegistration;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController(), _confirm = TextEditingController();
  _Page _page = _Page.signIn;
  bool _busy = false, _obscure = true;
  bool _ageConfirmed = false, _termsAccepted = false, _privacyAccepted = false;
  IdentityApplication? _identityApplication;
  String? _identityApplicationIdempotencyKey;
  IdentityProvisioningAuthorization? _identityProvisioningAuthorization;
  IdentityApplicationStatus? _identityStatus;
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
        break;
      case AuthEntryMode.verifyEmail:
        _page = _Page.verify;
        if (entry.hasCompleteCallback) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _verify(entry.userId!, entry.secret!),
          );
        } else {
          _notice = 'Open the complete verification link from your email, or request another one.';
        }
        break;
      case AuthEntryMode.signUp:
        if (widget.enableIdentityRegistration) {
          _page = _Page.signUp;
        } else {
          _page = _Page.signIn;
          _notice = 'Registration is temporarily unavailable. Please try again later.';
        }
        break;
      case AuthEntryMode.forgotPassword:
        _page = _Page.forgot;
        break;
      case AuthEntryMode.signIn:
        if (widget.requireVerification) {
          _page = _Page.verify;
          _notice = 'Verify your email address before using Testagram.';
        }
        break;
    }
    if (widget.requireIdentityReview) {
      if (widget.enableIdentityRegistration) {
        _page = _Page.signUp;
        _notice = 'Complete identity verification and independent account approval to finish setting up your account.';
      } else {
        _page = _Page.signIn;
        _notice = 'This account has not completed identity review and two-person approval. Registration is temporarily unavailable.';
      }
    }
  }

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _username.dispose(); _password.dispose(); _confirm.dispose(); super.dispose();
  }

  void _go(_Page p) {
    if (p == _Page.signUp && !widget.enableIdentityRegistration) return;
    setState(() { _page = p; _error = null; _notice = null; });
  }

  Widget _modeNavigation() {
    if (_page == _Page.identity) return const SizedBox.shrink();
    final modes = <(_Page, String)>[
      (_Page.signIn, 'Sign in'),
      if (widget.enableIdentityRegistration) (_Page.signUp, 'Sign up'),
      (_Page.forgot, 'Reset password'),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final mode in modes)
          ChoiceChip(
            label: Text(mode.$2),
            selected: _page == mode.$1,
            onSelected: _busy ? null : (_) => _go(mode.$1),
            showCheckmark: false,
          ),
      ],
    );
  }

  String? _emailValid(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) {
      return 'Enter your email address.';
    }
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s) ? null : 'Enter a valid email address.';
  }
  String? _passwordValid(String? v) =>
      v == null || v.length < 8 ? 'Use at least 8 characters.' : v.length > 256 ? 'Password is too long.' : null;

  String _friendly(Object e) {
    if (e is IdentityVerificationException) return e.message;
    if (e is BackendApiException) {
      if (e.statusCode == 403 && e.message.toLowerCase().contains('registration consent')) {
        return 'Confirm your age and accept the current Terms and Privacy Notice to finish account setup.';
      }
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
        return 'Your Appwrite sign-in succeeded, but Testagram could not resolve your canonical account. Retry or contact support.';
      }
      return e.message;
    }
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

  String _newIdentityIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String? _usernameValid(String? value) {
    final username = (value ?? '').trim().replaceFirst(RegExp(r'^@'), '');
    if (!RegExp(r'^[a-zA-Z0-9_]{3,30}$').hasMatch(username)) {
      return 'Use 3–30 letters, numbers or underscores.';
    }
    return null;
  }

  Future<void> _signIn() async {
    if (!_form.currentState!.validate()) return;
    await _run(() async {
      await widget.account.createEmailPasswordSession(
        email: _email.text.trim().toLowerCase(),
        password: _password.text,
      );
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

      final backend = BackendApi(
        baseUri: AppConfig.backendOrigin,
        getJwt: () async => (await widget.account.createJWT()).jwt,
      );
      try {
        await backend.getMyProfile();
      } on BackendApiException catch (error) {
        final message = error.message.toLowerCase();
        if (error.statusCode == 403 &&
            (message.contains('identity review') ||
             message.contains('two-person account approval') ||
             message.contains('registration consent'))) {
          if (mounted) {
            setState(() {
              _name.text = user.name;
              _email.text = user.email;
              _username.text = user.email.split('@').first
                  .toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_')
                  .replaceAll(RegExp(r'_+'), '_');
              if (_username.text.length < 3) _username.text = 'user_account';
              if (_username.text.length > 30) _username.text = _username.text.substring(0, 30);
              _page = widget.enableIdentityRegistration ? _Page.signUp : _Page.signIn;
              _notice = widget.enableIdentityRegistration
                  ? 'Your Appwrite login is valid, but this account has not completed Testagram identity review and two-person approval. Submit an application to continue.'
                  : 'Your Appwrite login is valid, but this account has not completed identity review and two-person approval. Registration is temporarily unavailable.';
            });
          }
          return;
        }
        rethrow;
      } finally {
        backend.close();
      }
      widget.onSignedIn();
    });
  }

  Future<void> _signUp() async {
    if (!_form.currentState!.validate()) return;
    if (!_ageConfirmed || !_termsAccepted || !_privacyAccepted) {
      setState(() => _error = 'Confirm your age and accept both policy documents to continue.');
      return;
    }
    await _run(() async {
      final api = IdentityVerificationClient(backendOrigin: AppConfig.backendOrigin);
      try {
        final application = await api.createApplication(
          email: _email.text.trim().toLowerCase(),
          username: _username.text.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase(),
          displayName: _name.text.trim(),
          adultConfirmed: _ageConfirmed,
          termsAccepted: _termsAccepted,
          privacyAccepted: _privacyAccepted,
          idempotencyKey: _identityApplicationIdempotencyKey ??= _newIdentityIdempotencyKey(),
        );
        // Keep the application credentials in memory before the follow-up
        // status request. If status polling fails, the applicant can retry it
        // without accidentally submitting a second application.
        _identityApplicationIdempotencyKey = null;
        if (!mounted) return;
        setState(() {
          _identityApplication = application;
          _identityStatus = null;
          _page = _Page.identity;
          _notice = 'Your application has been created. Submit the requested private evidence; account creation becomes available only after independent review and two-person approval.';
        });
        final status = await api.getStatus(application);
        if (mounted) setState(() => _identityStatus = status);
      } finally {
        api.close();
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

  String _identityContentType(String filename) {
    final name = filename.toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    throw const FormatException('Choose a JPEG, PNG or WebP image.');
  }

  Future<void> _uploadIdentityEvidence() async {
    final application = _identityApplication;
    if (application == null) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    await _run(() async {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 15 * 1024 * 1024) {
        throw const FormatException('Evidence must be between 1 byte and 15 MiB.');
      }
      final contentType = _identityContentType(file.name);
      final api = IdentityVerificationClient(backendOrigin: AppConfig.backendOrigin);
      try {
        await api.uploadAndSubmitEvidence(
          application: application,
          bytes: bytes,
          contentType: contentType,
        );
        final status = await api.getStatus(application);
        if (mounted) {
          setState(() {
            _identityStatus = status;
            _notice = 'Evidence was securely uploaded and submitted for manual review.';
          });
        }
      } finally {
        api.close();
      }
    });
  }

  String? _identityPasswordValid(String? value) {
    if (value == null || value.length < 12) return 'Use at least 12 characters.';
    if (value.length > 128) return 'Password is too long.';
    return null;
  }

  Future<void> _completeIdentityProvisioning() async {
    final application = _identityApplication;
    if (application == null || _identityStatus?.status != 'approved') return;
    if (!_form.currentState!.validate()) return;
    await _run(() async {
      final api = IdentityVerificationClient(backendOrigin: AppConfig.backendOrigin);
      try {
        var authorization = _identityProvisioningAuthorization;
        if (authorization == null) {
          authorization = await api.requestProvisioningAuthorization(application);
          _identityProvisioningAuthorization = authorization;
        }
        try {
          await widget.account.create(
            userId: ID.unique(),
            email: _email.text.trim().toLowerCase(),
            password: _password.text,
            name: _name.text.trim(),
          );
        } on AppwriteException catch (error) {
          // A previous attempt may already have created the Appwrite identity.
          // Sign in with the same credentials and safely retry the backend link.
          if (error.code != 409) rethrow;
        }
        await widget.account.createEmailPasswordSession(
          email: _email.text.trim().toLowerCase(),
          password: _password.text,
        );
        final user = await widget.account.get();
        if (!user.emailVerification) {
          try {
            await widget.account.createVerification(
              url: '${AppConfig.authCallbackOrigin}/?mode=verification',
            );
          } on AppwriteException catch (error) {
            if (error.code != 409) rethrow;
          }
        }
        final jwt = await widget.account.createJWT();
        Map<String, dynamic> result;
        try {
          result = await api.redeemProvisioningAuthorization(
            application: application,
            authorization: authorization,
            appwriteJwt: jwt.jwt,
          );
        } on IdentityVerificationException catch (error) {
          if (error.statusCode != 409) rethrow;
          final latest = await api.getStatus(application);
          if (latest.status == 'approved') {
            authorization = await api.requestProvisioningAuthorization(application);
            _identityProvisioningAuthorization = authorization;
          }
          // If the first redemption committed but its response was lost, the
          // Backend recognizes the same Appwrite identity and safely returns
          // the existing canonical link without consuming a second grant.
          result = await api.redeemProvisioningAuthorization(
            application: application,
            authorization: authorization,
            appwriteJwt: jwt.jwt,
          );
        }
        _identityProvisioningAuthorization = null;
        if (!mounted) return;
        _password.clear();
        _confirm.clear();
        if (user.emailVerification) {
          widget.onSignedIn();
        } else {
          setState(() {
            _page = _Page.verify;
            _notice = result['email_verification_required'] == true
                ? 'Your Appwrite identity is linked. Check your email and verify it before signing in to Testagram.'
                : 'Your account is linked. Verify your email to continue.';
          });
        }
      } finally {
        api.close();
      }
    });
  }

  Future<void> _refreshIdentityStatus() async {
    final application = _identityApplication;
    if (application == null) return;
    await _run(() async {
      final api = IdentityVerificationClient(backendOrigin: AppConfig.backendOrigin);
      try {
        final status = await api.getStatus(application);
        if (mounted) {
          setState(() {
            _identityStatus = status;
            _notice = 'Application status refreshed.';
          });
        }
      } finally {
        api.close();
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final title = switch (_page) {
      _Page.signIn => 'Welcome back', _Page.signUp => 'Create your account',
      _Page.forgot => 'Reset your password', _Page.verify => 'Verify your email',
      _Page.reset => 'Choose a new password',
      _Page.identity => 'Identity verification',
    };
    final subtitle = switch (_page) {
      _Page.signIn => 'Sign in to your Testagram account.',
      _Page.signUp => 'Join Testagram with your email address.',
      _Page.forgot => 'We will send a secure password reset link.',
      _Page.verify => 'Check your inbox and verify your email address.',
      _Page.reset => 'Choose a strong password you have not used before.',
      _Page.identity => 'Submit private evidence and track your manual review.',
    };
    return Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24), child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.hub_rounded,
                    color: Theme.of(context).colorScheme.primary, size: 30),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('T social',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          )),
                    Text(
                      'Your world, in the conversation.',
                      softWrap: true,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _modeNavigation(),
          const SizedBox(height: 24),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  )),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center),
          const SizedBox(height: 28),
          if (_page == _Page.signUp) ...[
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
              validator: (value) => value == null || value.trim().length < 2 ? 'Enter your name.' : null,
            ),
            const SizedBox(height: 14),
          ],
          if (_page == _Page.signUp) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _username,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Username', prefixText: '@', border: OutlineInputBorder()),
              validator: _usernameValid,
            ),
          ],
          if ({_Page.signIn, _Page.signUp, _Page.forgot}.contains(_page))
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              validator: _emailValid,
            ),
          if ({_Page.signIn, _Page.reset}.contains(_page)) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: _page == _Page.signIn ? const [AutofillHints.password] : const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: _page == _Page.reset ? 'New password' : 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
              validator: _passwordValid,
              onFieldSubmitted: (_) { if (_page == _Page.signIn) _signIn(); },
            ),
          ],
          if (_page == _Page.reset) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: 'Confirm password', border: OutlineInputBorder()),
              validator: (value) => value != _password.text ? 'Passwords do not match.' : null,
            ),
          ],
          if (_page == _Page.signUp) ...[
            if (_page == _Page.signUp) Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_outlined, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Create your Testagram account', style: TextStyle(fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('Submit your details and private age-assurance evidence. Two independent reviewers must approve your application before an Appwrite account and Testagram profile can be created.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
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
              title: const Text('I accept the Terms and Conditions.'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _privacyAccepted,
              onChanged: _busy ? null : (value) => setState(() => _privacyAccepted = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I accept the Privacy Notice.'),
            ),
            Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
              TextButton(onPressed: _busy ? null : () => _showLegalDocument('Terms and Conditions', _termsText), child: const Text('Read Terms and Conditions')),
              TextButton(onPressed: _busy ? null : () => _showLegalDocument('Privacy Notice', _privacyText), child: const Text('Read Privacy Notice')),
            ]),
            const SizedBox(height: 8),
          ],
          if (_page == _Page.identity) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Application submitted', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Application: ${_identityApplication?.applicationId ?? '—'}'),
                  Text('Status: ${_identityStatus?.status ?? 'awaiting evidence'}'),
                  Text('Age assurance: ${_identityStatus?.verificationStatus ?? 'pending'}'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _uploadIdentityEvidence,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Choose and submit evidence'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _refreshIdentityStatus,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh application status'),
                  ),
                  if (_identityStatus?.status == 'approved') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: const InputDecoration(labelText: 'Create password', border: OutlineInputBorder()),
                      validator: _identityPasswordValid,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _obscure,
                      decoration: const InputDecoration(labelText: 'Confirm password', border: OutlineInputBorder()),
                      validator: (value) => value != _password.text ? 'Passwords do not match.' : null,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : _completeIdentityProvisioning,
                      child: _busy ? const CircularProgressIndicator() : const Text('Create and link my account'),
                    ),
                  ],
                ]),
              ),
            ),
          ],
          if (_error != null) ...[const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
          if (_notice != null) ...[const SizedBox(height: 14),
            Text(_notice!, style: TextStyle(color: Theme.of(context).colorScheme.primary))],
          const SizedBox(height: 20),
          if (_page == _Page.signIn) FilledButton(onPressed: _busy ? null : _signIn,
            child: _busy ? const CircularProgressIndicator() : const Text('Sign in')),
          if (_page == _Page.signUp)
            FilledButton(
              onPressed: _busy ? null : _signUp,
              child: _busy ? const CircularProgressIndicator() : const Text('Submit identity application'),
            ),
          if (_page == _Page.forgot) FilledButton(onPressed: _busy ? null : _forgot,
            child: _busy ? const CircularProgressIndicator() : const Text('Send reset link')),
          if (_page == _Page.reset) FilledButton(onPressed: _busy ? null : _reset,
            child: _busy ? const CircularProgressIndicator() : const Text('Update password')),
          if (_page == _Page.verify) OutlinedButton(onPressed: _busy ? null : _resend,
            child: const Text('Resend verification email')),
          const SizedBox(height: 12),
          if (_page == _Page.signIn) ...[
            TextButton(onPressed: _busy ? null : () => _go(_Page.forgot), child: const Text('Forgot password?')),
            if (widget.enableIdentityRegistration) ...[
              const SizedBox(height: 4),
              Text('New to Testagram?', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 6),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _go(_Page.signUp),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Create account'),
              ),
            ],
          ] else if (_page != _Page.verify)
            TextButton(onPressed: _busy ? null : () => _go(_Page.signIn), child: const Text('Back to sign in')),
          const SizedBox(height: 12),
          Text(
            'Appwrite authenticates accounts. Testagram Backend remains responsible for canonical profile linking and product authorization.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
        ])),
      ),
    ))));
  }
}