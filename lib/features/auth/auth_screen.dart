
import 'dart:convert';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/app_config.dart';
import '../../core/backend_api.dart';
import '../../core/auth/native_auth_client.dart';
import '../../core/widgets/testagram_brand_mark.dart';
import '../../core/testagram_theme.dart';
import 'auth_entry.dart';
import 'identity_verification_client.dart';
import 'identity_application_store.dart';

enum _Page { signIn, signUp, forgot, verify, reset, identity }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authClient,
    required this.onSignedIn,
    this.requireVerification = false,
    this.requireIdentityReview = false,
    this.initialEmail,
    this.enableIdentityRegistration = false,
    this.identityApplicationStore,
  });
  final NativeAuthSession authClient;
  final VoidCallback onSignedIn;
  final bool requireVerification;
  final bool requireIdentityReview;
  final String? initialEmail;
  final bool enableIdentityRegistration;
  final IdentityApplicationStore? identityApplicationStore;
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
  late final IdentityApplicationStore _identityStore;
  IdentityApplicationDraft? _identityDraft;
  IdentityApplication? _identityApplication;
  IdentityProvisioningAuthorization? _identityProvisioningAuthorization;
  IdentityApplicationStatus? _identityStatus;
  String? _error, _notice, _recoveryToken;

  @override
  void initState() {
    super.initState();
    _identityStore = widget.identityApplicationStore ?? IdentityApplicationStore();
    _email.text = widget.initialEmail ?? '';
    final entry = AuthEntry.fromUri(Uri.base);
    switch (entry.mode) {
      case AuthEntryMode.resetPassword:
        _recoveryToken = entry.token;
        _page = _Page.reset;
        if (!entry.hasCompleteCallback) {
          _error = 'This password reset link is incomplete. Request a new reset email.';
        }
        break;
      case AuthEntryMode.verifyEmail:
        _page = _Page.verify;
        if (entry.hasCompleteCallback) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _verify(entry.applicationId!, entry.token!),
          );
        } else {
          _notice = 'Open the complete Testagram verification link from your email, or request another one.';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSavedIdentityApplication());
  }

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _username.dispose(); _password.dispose(); _confirm.dispose(); super.dispose();
  }

  void _go(_Page p) {
    if (p == _Page.signUp && !widget.enableIdentityRegistration) return;
    setState(() { _page = p; _error = null; _notice = null; });
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
      if (e.code == 'IDENTITY_APPROVAL_REQUIRED') {
        return 'Identity review and two-person account approval are required before accessing Testagram.';
      }
      if (e.code == 'EMAIL_VERIFICATION_REQUIRED') {
        return 'Verify your email address before accessing Testagram.';
      }
      if (e.code == 'AUTH_BACKEND_UNAVAILABLE') {
        return 'Testagram authentication is temporarily unavailable. Please retry.';
      }
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
        return 'Testagram could not confirm your account. Retry or contact support.';
      }
      return e.message;
    }
    if (e is NativeAuthException) {
      if (e.code == 'EMAIL_VERIFICATION_REQUIRED') {
        return 'Verify your email address before signing in.';
      }
      if (e.statusCode == 401) {
        return 'The email or password is incorrect.';
      }
      if (e.statusCode == 409) {
        return 'This account or application conflicts with an existing Testagram record. Check your details or contact support.';
      }
      if (e.statusCode == 429) {
        return 'Too many attempts. Wait and retry.';
      }
      return e.message;
    }
    final s = e.toString();
    if (s.contains('ClientException') || s.contains('Failed to fetch') ||
        s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'Cannot reach Testagram. Check your connection and retry.';
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
      try {
        await widget.authClient.signIn(
          email: _email.text.trim().toLowerCase(),
          password: _password.text,
        );
      } on NativeAuthException catch (error) {
        if (error.code == 'EMAIL_VERIFICATION_REQUIRED') {
          if (mounted) {
            setState(() {
              _page = _Page.verify;
              _notice = 'Your password is correct, but your Testagram email is not verified yet. Check your inbox or request a fresh link from your saved application.';
            });
          }
          return;
        }
        if (error.code == 'IDENTITY_APPROVAL_REQUIRED') {
          if (mounted) {
            setState(() {
              _page = widget.enableIdentityRegistration ? _Page.signUp : _Page.signIn;
              _notice = widget.enableIdentityRegistration
                  ? 'This account has not completed Testagram identity review and two-person account approval. Submit an application to continue.'
                  : 'This account has not completed identity review and two-person account approval. Registration is temporarily unavailable.';
            });
          }
          return;
        }
        rethrow;
      }
      final backend = BackendApi(
        baseUri: AppConfig.backendOrigin,
        getAccessToken: widget.authClient.accessToken,
      );
      try {
        await backend.getMyProfile();
      } on BackendApiException catch (error) {
        final message = error.message.toLowerCase();
        if (error.statusCode == 403 &&
            (error.code == 'IDENTITY_APPROVAL_REQUIRED' ||
                message.contains('identity review') ||
                message.contains('two-person account approval'))) {
          if (mounted) {
            setState(() {
              _email.text = _email.text.trim().toLowerCase();
              _username.text = _email.text.split('@').first
                  .toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_')
                  .replaceAll(RegExp(r'_+'), '_');
              if (_username.text.length < 3) _username.text = 'user_account';
              if (_username.text.length > 30) {
                _username.text = _username.text.substring(0, 30);
              }
              _page = widget.enableIdentityRegistration ? _Page.signUp : _Page.signIn;
              _notice = widget.enableIdentityRegistration
                  ? 'This Testagram account has not completed identity review and two-person approval. Submit an application to continue.'
                  : 'This account has not completed identity review and two-person approval. Registration is temporarily unavailable.';
            });
          }
          return;
        }
        if (error.statusCode == 403 && error.code == 'EMAIL_VERIFICATION_REQUIRED') {
          if (mounted) {
            setState(() {
              _page = _Page.verify;
              _notice = 'Verify the email address linked to your approved Testagram application before signing in.';
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

  Future<IdentityApplication?> _submitIdentityDraft(
    IdentityVerificationClient api,
    IdentityApplicationDraft draft,
  ) async {
    final result = await api.createApplication(
      email: draft.email,
      username: draft.username,
      displayName: draft.displayName,
      adultConfirmed: true,
      termsAccepted: true,
      privacyAccepted: true,
      idempotencyKey: draft.idempotencyKey,
    );
    final application = result.application;
    if (application != null) return application;

    // A generic 202 is intentionally indistinguishable from an ineligible or
    // already-existing address. It is not an application capability and must
    // never be shown as a created application or retried after app restart.
    await _identityStore.clear();
    if (mounted) {
      setState(() {
        _identityDraft = null;
        _identityApplication = null;
        _identityStatus = null;
        _identityProvisioningAuthorization = null;
        _page = _Page.signIn;
        _notice = result.message;
        _error = null;
      });
    }
    return null;
  }

  Future<void> _restoreSavedIdentityApplication() async {
    IdentityApplicationDraft? draft;
    try {
      draft = await _identityStore.load();
    } catch (_) {
      // Secure storage can be unavailable in an unsupported browser context.
      // Do not submit a new application when its recovery key cannot be saved.
      return;
    }
    if (draft == null || !mounted) return;
    final restoredDraft = draft;
    setState(() {
      _identityDraft = restoredDraft;
      _identityApplication = restoredDraft.application;
      _name.text = restoredDraft.displayName;
      _email.text = restoredDraft.email;
      _username.text = restoredDraft.username;
      _page = _Page.identity;
      _notice = 'Your saved identity application was restored. Your password is never stored; create it only after approval.';
    });
    final api = IdentityVerificationClient(backendOrigin: AppConfig.backendOrigin);
    try {
      var currentDraft = restoredDraft;
      late IdentityApplication application;
      if (currentDraft.application == null) {
        final created = await _submitIdentityDraft(api, currentDraft);
        if (created == null) return;
        application = created;
        currentDraft = currentDraft.copyWith(application: application);
        await _identityStore.save(currentDraft);
      } else {
        application = currentDraft.application!;
      }
      IdentityApplicationStatus status;
      try {
        status = await api.getStatus(application);
      } on IdentityVerificationException catch (error) {
        if (error.statusCode != 404) rethrow;
        final created = await _submitIdentityDraft(api, currentDraft);
        if (created == null) return;
        application = created;
        currentDraft = currentDraft.copyWith(application: application);
        await _identityStore.save(currentDraft);
        status = await api.getStatus(application);
      }
      if (application.sessionId.isNotEmpty && application.sessionToken.isNotEmpty) {
        try {
          await api.getSessionExpiry(application);
        } on IdentityVerificationException catch (error) {
          if (error.statusCode != 404) rethrow;
          final created = await _submitIdentityDraft(api, currentDraft);
          if (created == null) return;
          application = created;
          currentDraft = currentDraft.copyWith(application: application);
          await _identityStore.save(currentDraft);
          status = await api.getStatus(application);
        }
      }
      if (status.provisioningStatus == 'active') {
        try {
          await _identityStore.clear();
        } catch (_) {}
        if (mounted) {
          setState(() {
            _identityDraft = null;
            _identityApplication = null;
            _identityStatus = status;
            _page = _Page.signIn;
            _notice = 'Your Testagram account is active. Sign in with your Testagram password.';
          });
        }
      } else if (mounted) {
        setState(() {
          _identityDraft = currentDraft;
          _identityApplication = application;
          _identityStatus = status;
          _page = status.provisioningStatus == 'verification_pending'
              ? _Page.verify
              : _Page.identity;
          _notice = status.provisioningStatus == 'verification_pending'
              ? 'Your Testagram account has been created. Verify your email to activate it.'
              : 'Your application is ready to continue. Refresh its status at any time.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Your saved application could not be refreshed. Check your connection and retry.';
        });
      }
    } finally {
      api.close();
    }
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
        var draft = _identityDraft;
        if (draft == null) {
          final newDraft = IdentityApplicationDraft(
            email: _email.text.trim().toLowerCase(),
            username: _username.text.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase(),
            displayName: _name.text.trim(),
            idempotencyKey: _newIdentityIdempotencyKey(),
            createdAt: DateTime.now().toUtc(),
          );
          // Persist the idempotency capability before the network request so
          // a lost response can be recovered after an app/browser restart.
          await _identityStore.save(newDraft);
          draft = newDraft;
          _identityDraft = newDraft;
          if (mounted) setState(() {});
        }
        final submissionDraft = draft;
        final application = await _submitIdentityDraft(api, submissionDraft);
        if (application == null) return;
        final savedDraft = submissionDraft.copyWith(application: application);
        await _identityStore.save(savedDraft);
        if (!mounted) return;
        setState(() {
          _identityDraft = savedDraft;
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
    final application = _identityApplication;
    if (application == null) {
      if (mounted) {
        setState(() => _notice =
            'If your approved application is awaiting email verification, reopen it on this device to request a new link.');
      }
      return;
    }
    final api = IdentityVerificationClient(backendOrigin: AppConfig.backendOrigin);
    try {
      await api.resendVerification(application);
      if (mounted) {
        setState(() => _notice =
            'If your approved application is awaiting verification, a fresh Testagram email link has been requested.');
      }
    } finally {
      api.close();
    }
  });

  Future<void> _verify(String applicationId, String token) async => _run(() async {
    final api = IdentityVerificationClient(backendOrigin: AppConfig.backendOrigin);
    try {
      await api.verifyEmail(applicationId: applicationId, token: token);
      try {
        await _identityStore.clear();
      } catch (_) {
        // The server has consumed the one-time token; local cleanup is best-effort.
      }
      if (mounted) {
        setState(() {
          _identityDraft = null;
          _identityApplication = null;
          _identityStatus = null;
          _identityProvisioningAuthorization = null;
          _recoveryToken = null;
          _page = _Page.signIn;
          _notice = 'Your Testagram email is verified. Sign in with your new Testagram password.';
        });
      }
    } finally {
      api.close();
    }
  });

  Future<void> _forgot() async {
    if (!_form.currentState!.validate()) return;
    await _run(() async {
      await widget.authClient.requestPasswordReset(_email.text.trim().toLowerCase());
      if (mounted) {
        setState(() {
          _page = _Page.signIn;
          _notice = 'If the account exists, a Testagram password reset link has been sent.';
        });
      }
    });
  }

  Future<void> _reset() async {
    if (!_form.currentState!.validate()) return;
    if (_recoveryToken == null || _recoveryToken!.isEmpty) {
      setState(() {
        _error = 'Recovery link is incomplete. Request a new reset email.';
      });
      return;
    }
    await _run(() async {
      try {
        await widget.authClient.resetPassword(
          token: _recoveryToken!,
          password: _password.text,
        );
      } on NativeAuthException catch (error) {
        if (error.statusCode == 400 || error.statusCode == 401 || error.statusCode == 404) {
          if (mounted) {
            setState(() => _error =
                'This reset link is invalid, expired or already used. Request a new reset email.');
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
          _recoveryToken = null;
          _notice = 'Password changed. Sign in with your new Testagram password.';
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

        Map<String, dynamic> result;
        try {
          result = await api.redeemProvisioningAuthorization(
            application: application,
            authorization: authorization,
            password: _password.text,
          );
        } on IdentityVerificationException catch (error) {
          if (error.statusCode != 409) rethrow;
          final latest = await api.getStatus(application);
          if (latest.status == 'approved') {
            // The short-lived approval grant may have expired before redemption.
            authorization = await api.requestProvisioningAuthorization(application);
            _identityProvisioningAuthorization = authorization;
          }
          // If the first request committed but its response was lost, the same
          // consumed grant returns the same native account without resetting its
          // password or creating a duplicate profile.
          result = await api.redeemProvisioningAuthorization(
            application: application,
            authorization: authorization,
            password: _password.text,
          );
        }

        final status = await api.getStatus(application);
        _identityProvisioningAuthorization = null;
        if (!mounted) return;
        _password.clear();
        _confirm.clear();
        setState(() {
          _identityStatus = status;
          _page = _Page.verify;
          _notice = result['email_delivery_pending'] == true
              ? 'Your identity application is approved and your Testagram account has been created. Email delivery is being retried; use Resend verification when the email service is available.'
              : 'Your identity application is approved and your Testagram account has been created. Check your email and verify it before signing in.';
        });
      } finally {
        api.close();
      }
    });
  }

  Future<void> _refreshIdentityStatus() async {
    if (_identityApplication == null || _identityDraft == null) return;
    var application = _identityApplication!;
    var currentDraft = _identityDraft!;
    await _run(() async {
      final api = IdentityVerificationClient(backendOrigin: AppConfig.backendOrigin);
      try {
        IdentityApplicationStatus status;
        try {
          status = await api.getStatus(application);
        } on IdentityVerificationException catch (error) {
          if (error.statusCode != 404) rethrow;
          final created = await _submitIdentityDraft(api, currentDraft);
          if (created == null) return;
          application = created;
          currentDraft = currentDraft.copyWith(application: application);
          await _identityStore.save(currentDraft);
          status = await api.getStatus(application);
        }
        if (application.sessionId.isNotEmpty && application.sessionToken.isNotEmpty) {
          try {
            await api.getSessionExpiry(application);
          } on IdentityVerificationException catch (error) {
            if (error.statusCode != 404) rethrow;
            final created = await _submitIdentityDraft(api, currentDraft);
            if (created == null) return;
            application = created;
            currentDraft = currentDraft.copyWith(application: application);
            await _identityStore.save(currentDraft);
            status = await api.getStatus(application);
          }
        }
        if (status.provisioningStatus == 'active') {
          try {
            await _identityStore.clear();
          } catch (_) {}
          if (mounted) {
            setState(() {
              _identityDraft = null;
              _identityApplication = null;
              _identityStatus = status;
              _page = _Page.signIn;
              _notice = 'Your Testagram account is active. Sign in with your Testagram password.';
            });
          }
        } else if (mounted) {
          setState(() {
            _identityDraft = currentDraft;
            _identityApplication = application;
            _identityStatus = status;
            _page = status.provisioningStatus == 'verification_pending'
                ? _Page.verify
                : _Page.identity;
            _notice = status.provisioningStatus == 'verification_pending'
                ? 'Your Testagram account has been created. Verify your email to activate it.'
                : 'Application status refreshed.';
          });
        }
      } finally {
        api.close();
      }
    });
  }

  Future<void> _startNewIdentityApplication() async {
    await _identityStore.clear();
    if (!mounted) return;
    setState(() {
      _identityDraft = null;
      _identityApplication = null;
      _identityStatus = null;
      _identityProvisioningAuthorization = null;
      _ageConfirmed = false;
      _termsAccepted = false;
      _privacyAccepted = false;
      _password.clear();
      _confirm.clear();
      _page = widget.enableIdentityRegistration ? _Page.signUp : _Page.signIn;
      _notice = widget.enableIdentityRegistration
          ? 'You can submit a new application with updated details.'
          : 'Registration is temporarily unavailable.';
      _error = null;
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
      _Page.signIn => 'Welcome back',
      _Page.signUp => 'Join the conversation',
      _Page.forgot => 'Reset your password',
      _Page.verify => 'Verify your email',
      _Page.reset => 'Choose a new password',
      _Page.identity => 'Identity verification',
    };
    final subtitle = switch (_page) {
      _Page.signIn => 'Sign in to catch up with your people.',
      _Page.signUp => 'Create your place in the conversation.',
      _Page.forgot => 'We’ll send a secure link if an account matches that email.',
      _Page.verify => 'One quick step to secure your Testagram account.',
      _Page.reset => 'Choose a strong password you haven’t used before.',
      _Page.identity => 'Complete your application and follow its review status.',
    };
    final theme = Theme.of(context);
    const ink = TestagramTheme.ink;
    const muted = TestagramTheme.mutedInk;
    const blue = TestagramTheme.blue;
    const pale = Color(0xFFEAF2FF);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? TestagramTheme.darkSurface : TestagramTheme.lightSurface;
    final raised = isDark ? TestagramTheme.darkRaised : TestagramTheme.lightRaised;
    final border = isDark ? TestagramTheme.darkBorder : TestagramTheme.lightBorder;

    Widget field({
      required TextEditingController controller,
      required String label,
      required IconData icon,
      String? Function(String?)? validator,
      TextInputType? keyboardType,
      Iterable<String>? autofillHints,
      bool obscure = false,
      bool readOnly = false,
      Widget? suffix,
      TextInputAction? action,
      void Function(String)? onSubmitted,
      String? prefix,
      TextCapitalization capitalization = TextCapitalization.none,
      bool autocorrect = true,
    }) {
      return TextFormField(
        controller: controller,
        readOnly: readOnly,
        obscureText: obscure,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        textInputAction: action,
        textCapitalization: capitalization,
        autocorrect: autocorrect,
        validator: validator,
        onFieldSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          prefixText: prefix,
          suffixIcon: suffix,
          filled: true,
          fillColor: raised,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 19),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE0E9E3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: blue, width: 1.8),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.colorScheme.error),
          ),
        ),
      );
    }

    Widget modeSwitch() {
      final modes = <(_Page, String)>[
        (_Page.signIn, 'Sign in'),
        if (widget.enableIdentityRegistration) (_Page.signUp, 'Sign up'),
        (_Page.forgot, 'Reset password'),
      ];
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: raised,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            for (final mode in modes)
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _busy ? null : () => _go(mode.$1),
                    borderRadius: BorderRadius.circular(10),
                    child: Semantics(
                      button: true,
                      selected: _page == mode.$1,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 5),
                        decoration: BoxDecoration(
                          color: _page == mode.$1 ? (isDark ? const Color(0xFF203A5D) : surface) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _page == mode.$1 && !isDark
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              mode.$2,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: TextStyle(
                                color: _page == mode.$1 ? (isDark ? Colors.white : ink) : muted,
                                fontWeight: _page == mode.$1 ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    Widget statusMessage(String message, {required bool error}) {
      final color = error ? theme.colorScheme.error : blue;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(error ? Icons.error_outline_rounded : Icons.info_outline_rounded, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(color: isDark ? Colors.white : ink, height: 1.4))),
          ],
        ),
      );
    }

    Widget primaryAction(String label, VoidCallback? action) => SizedBox(
      height: 54,
      width: double.infinity,
      child: FilledButton(
        onPressed: _busy ? null : action,
        style: FilledButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: blue.withValues(alpha: 0.48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: _busy
            ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label),
      ),
    );

    Widget formContent({required bool compact}) {
      return Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              Row(
                children: [
                  const TestagramBrandMark(size: 46, radius: 14),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Testagram', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.8, color: isDark ? Colors.white : ink)),
                        const Text('A social world that moves with you', style: TextStyle(fontSize: 11, color: muted)),
                      ],
                    ),
                  ),
                  Icon(Icons.public_rounded, color: blue.withValues(alpha: 0.8), size: 22),
                ],
              ),
              const SizedBox(height: 28),
            ],
            modeSwitch(),
            const SizedBox(height: 28),
            Text(title, style: TextStyle(fontSize: compact ? 29 : 32, height: 1.12, letterSpacing: -1.0, fontWeight: FontWeight.w800, color: isDark ? Colors.white : ink)),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(fontSize: 14, height: 1.5, color: muted)),
            const SizedBox(height: 24),
            if (_page == _Page.signUp) ...[
              field(controller: _name, label: 'Full name', icon: Icons.person_outline_rounded, readOnly: _identityDraft != null, capitalization: TextCapitalization.words, action: TextInputAction.next, validator: (v) => v == null || v.trim().length < 2 ? 'Enter your name.' : null),
              const SizedBox(height: 14),
              field(controller: _username, label: 'Username', icon: Icons.alternate_email_rounded, prefix: '@', readOnly: _identityDraft != null, autocorrect: false, action: TextInputAction.next, validator: _usernameValid),
              const SizedBox(height: 14),
            ],
            if ({_Page.signIn, _Page.signUp, _Page.forgot}.contains(_page)) ...[
              field(controller: _email, label: 'Email address', icon: Icons.mail_outline_rounded, readOnly: _identityDraft != null, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], autocorrect: false, action: TextInputAction.next, validator: _emailValid),
              const SizedBox(height: 14),
            ],
            if ({_Page.signIn, _Page.reset}.contains(_page)) ...[
              field(
                controller: _password,
                label: _page == _Page.reset ? 'New password' : 'Password',
                icon: Icons.lock_outline_rounded,
                obscure: _obscure,
                autofillHints: _page == _Page.signIn ? const [AutofillHints.password] : const [AutofillHints.newPassword],
                validator: _passwordValid,
                action: _page == _Page.signIn ? TextInputAction.done : TextInputAction.next,
                onSubmitted: (_) { if (_page == _Page.signIn) _signIn(); },
                suffix: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (_page == _Page.reset) ...[
              field(controller: _confirm, label: 'Confirm new password', icon: Icons.lock_reset_rounded, obscure: _obscure, validator: (v) => v != _password.text ? 'Passwords do not match.' : null),
              const SizedBox(height: 14),
            ],
            if (_page == _Page.signUp) ...[
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: pale.withValues(alpha: isDark ? 0.12 : 1), borderRadius: BorderRadius.circular(16), border: Border.all(color: green.withValues(alpha: 0.18))),
                child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.verified_user_outlined, color: green, size: 21),
                  SizedBox(width: 11),
                  Expanded(child: Text('Account safety comes first. Your application is reviewed independently before account activation.', style: TextStyle(height: 1.45, fontSize: 13))),
                ]),
              ),
              const SizedBox(height: 12),
              Material(
                color: Colors.transparent,
                child: CheckboxListTile(contentPadding: EdgeInsets.zero, value: _ageConfirmed, onChanged: _busy ? null : (v) => setState(() => _ageConfirmed = v ?? false), controlAffinity: ListTileControlAffinity.leading, title: const Text('I confirm that I am 18 years old or above.'), dense: true),
              ),
              Material(
                color: Colors.transparent,
                child: CheckboxListTile(contentPadding: EdgeInsets.zero, value: _termsAccepted, onChanged: _busy ? null : (v) => setState(() => _termsAccepted = v ?? false), controlAffinity: ListTileControlAffinity.leading, title: const Text('I accept the Terms and Conditions.'), dense: true),
              ),
              Material(
                color: Colors.transparent,
                child: CheckboxListTile(contentPadding: EdgeInsets.zero, value: _privacyAccepted, onChanged: _busy ? null : (v) => setState(() => _privacyAccepted = v ?? false), controlAffinity: ListTileControlAffinity.leading, title: const Text('I accept the Privacy Notice.'), dense: true),
              ),
              Wrap(alignment: WrapAlignment.start, spacing: 8, children: [
                TextButton(onPressed: _busy ? null : () => _showLegalDocument('Terms and Conditions', _termsText), child: const Text('Read terms')),
                TextButton(onPressed: _busy ? null : () => _showLegalDocument('Privacy Notice', _privacyText), child: const Text('Read privacy notice')),
              ]),
              const SizedBox(height: 8),
            ],
            if (_page == _Page.identity) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: pale.withValues(alpha: isDark ? 0.12 : 1), borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Your application', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('Reference: ${_identityApplication?.applicationId ?? '—'}'),
                  Text('Status: ${_identityStatus?.status ?? 'awaiting evidence'}'),
                  Text('Age assurance: ${_identityStatus?.verificationStatus ?? 'pending'}'),
                  const SizedBox(height: 14),
                  if (_identityApplication?.sessionId.isNotEmpty == true && _identityApplication?.sessionToken.isNotEmpty == true && _identityStatus?.status == 'verification_pending')
                    FilledButton.icon(onPressed: _busy ? null : _uploadIdentityEvidence, icon: const Icon(Icons.upload_file), label: const Text('Submit evidence')),
                  OutlinedButton.icon(onPressed: _busy ? null : _refreshIdentityStatus, icon: const Icon(Icons.refresh), label: const Text('Refresh status')),
                  if (const {'rejected', 'expired', 'cancelled'}.contains(_identityStatus?.status) && widget.enableIdentityRegistration)
                    OutlinedButton.icon(onPressed: _busy ? null : _startNewIdentityApplication, icon: const Icon(Icons.refresh), label: const Text('Start a new application')),
                  if (_identityStatus?.status == 'approved') ...[
                    const SizedBox(height: 14),
                    field(controller: _password, label: 'Create password', icon: Icons.lock_outline_rounded, obscure: _obscure, validator: _identityPasswordValid),
                    const SizedBox(height: 12),
                    field(controller: _confirm, label: 'Confirm password', icon: Icons.lock_reset_rounded, obscure: _obscure, validator: (v) => v != _password.text ? 'Passwords do not match.' : null),
                    const SizedBox(height: 12),
                    primaryAction('Create and link my account', _completeIdentityProvisioning),
                  ],
                ]),
              ),
            ],
            if (_error != null) ...[const SizedBox(height: 16), statusMessage(_error!, error: true)],
            if (_notice != null) ...[const SizedBox(height: 16), statusMessage(_notice!, error: false)],
            const SizedBox(height: 20),
            if (_page == _Page.signIn) primaryAction('Sign in', _signIn),
            if (_page == _Page.signUp) primaryAction('Submit application', _signUp),
            if (_page == _Page.forgot) primaryAction('Send reset link', _forgot),
            if (_page == _Page.reset) primaryAction('Update password', _reset),
            if (_page == _Page.verify)
              SizedBox(height: 52, child: OutlinedButton.icon(onPressed: _busy ? null : _resend, icon: const Icon(Icons.mark_email_read_outlined), label: const Text('Resend verification email'))),
            const SizedBox(height: 12),
            if (_page == _Page.signIn) ...[
              Align(alignment: Alignment.center, child: TextButton(onPressed: _busy ? null : () => _go(_Page.forgot), child: const Text('Forgot password?'))),
              if (widget.enableIdentityRegistration) ...[
                const SizedBox(height: 8),
                const Row(children: [
                  Expanded(child: Divider()),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('NEW HERE?', style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: muted, fontWeight: FontWeight.w700))),
                  Expanded(child: Divider()),
                ]),
                const SizedBox(height: 12),
                SizedBox(height: 52, child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _go(_Page.signUp),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Create your account'),
                  style: OutlinedButton.styleFrom(foregroundColor: green, side: const BorderSide(color: Color(0xFFB8D8C3)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                )),
              ],
            ] else if (_page != _Page.verify)
              Align(alignment: Alignment.center, child: TextButton(onPressed: _busy ? null : () => _go(_Page.signIn), child: const Text('Back to sign in'))),
            const SizedBox(height: 18),
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.shield_outlined, size: 15, color: muted),
              SizedBox(width: 6),
              Flexible(child: Text('Secure sign-in, built by Testagram', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: muted))),
            ]),
          ],
        ),
      );
    }

    Widget brandPanel() => Container(
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B3B88), Color(0xFF146EF5), Color(0xFF0756C9)]),
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Row(children: [
          TestagramBrandMark(size: 54, radius: 16),
          SizedBox(width: 13),
          Text('Testagram', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
        ]),
        const SizedBox(height: 36),
        const Text('More than a feed.\nA world of voices.', style: TextStyle(color: Colors.white, fontSize: 39, height: 1.08, fontWeight: FontWeight.w900, letterSpacing: -1.6)),
        const SizedBox(height: 16),
        const Text('Follow what moves you. Share what matters. Find your people.', style: TextStyle(color: Color(0xFFDCEAFF), fontSize: 16, height: 1.55)),
        const SizedBox(height: 28),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final item in ['Your voice', 'Open conversations', 'Communities'])
            Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withValues(alpha: 0.2))), child: Text(item, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 34),
        const Text('ONE PLATFORM. MANY PERSPECTIVES.', style: TextStyle(color: Color(0xFFC3DAFF), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
      ]),
    );

    Widget mobileHero() => Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 54),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B3B88), Color(0xFF146EF5), Color(0xFF0756C9)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            TestagramBrandMark(size: 44, radius: 14),
            SizedBox(width: 12),
            Text('Testagram', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.7)),
            Spacer(),
            Icon(Icons.public_rounded, color: Color(0xFFDCEAFF), size: 22),
          ]),
          const SizedBox(height: 28),
          const Text(
            'More than a feed.\\nA world of voices.',
            style: TextStyle(color: Colors.white, fontSize: 30, height: 1.08, fontWeight: FontWeight.w900, letterSpacing: -1.1),
          ),
          const SizedBox(height: 10),
          const Text(
            'Follow what moves you. Share what matters. Find your people.',
            style: TextStyle(color: Color(0xFFDCEAFF), fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 18),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final item in ['Your voice', 'Open conversations', 'Communities'])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: Text(item, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ]),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: isDark ? TestagramTheme.darkBackground : TestagramTheme.lightBackground,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final compact = constraints.maxWidth < 600;
          if (wide) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Container(
                    decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, 18))]),
                    padding: const EdgeInsets.all(12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 690), child: brandPanel())),
                      const SizedBox(width: 12),
                      Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(40, 34, 40, 28), child: formContent(compact: false))),
                    ]),
                  ),
                ),
              ),
            );
          }
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    mobileHero(),
                    Transform.translate(
                      offset: const Offset(0, -28),
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: compact ? 14 : 28),
                        padding: EdgeInsets.fromLTRB(compact ? 20 : 30, compact ? 22 : 30, compact ? 20 : 30, 28),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.09),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: formContent(compact: compact),
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
