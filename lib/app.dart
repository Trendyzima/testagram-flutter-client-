import 'package:appwrite/appwrite.dart';
import 'package:material_ui/material_ui.dart';

import 'core/app_config.dart';
import 'core/backend_api.dart';
import 'core/native_auth_session.dart';
import 'core/testagram_theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/native_auth_screen.dart';
import 'app/main_shell.dart';

class TestagramApp extends StatefulWidget {
  const TestagramApp({super.key, this.account, this.nativeAuthSession});

  final Account? account;
  final NativeAuthSession? nativeAuthSession;

  @override
  State<TestagramApp> createState() => _TestagramAppState();
}

class _TestagramAppState extends State<TestagramApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    final configured = AppConfig.isConfigured &&
        (AppConfig.useNativeAuth ? widget.nativeAuthSession != null : widget.account != null);
    return MaterialApp(
      title: 'T social',
      debugShowCheckedModeBanner: false,
      theme: TestagramTheme.light(),
      darkTheme: TestagramTheme.dark(),
      themeMode: _themeMode,
      home: configured
          ? AuthGate(
              account: widget.account,
              nativeAuthSession: widget.nativeAuthSession,
              themeMode: _themeMode,
              onThemeModeChanged: (value) => setState(() => _themeMode = value),
            )
          : const _ConfigurationRequired(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.account,
    required this.nativeAuthSession,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final Account? account;
  final NativeAuthSession? nativeAuthSession;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _signedIn = false;
  bool _requiresVerification = false;
  bool _requiresIdentityReview = false;
  String? _restoreError;
  BackendApi? _api;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    if (mounted) setState(() => _loading = true);
    _restoreError = null;
    _requiresIdentityReview = false;
    if (AppConfig.useNativeAuth) {
      final session = widget.nativeAuthSession!;
      try {
        if (!await session.hasStoredSession()) {
          _signedIn = false;
          _requiresVerification = false;
        } else {
          await session.getAccessToken();
          final api = _createApi();
          try {
            await api.getMyProfile();
            _api = api;
            _signedIn = true;
            _requiresVerification = false;
          } catch (error) {
            api.close();
            if (error is BackendApiException && error.statusCode == 403 &&
                (error.code == 'IDENTITY_APPROVAL_REQUIRED' ||
                 error.message.toLowerCase().contains('identity review') ||
                 error.message.toLowerCase().contains('two-person account approval'))) {
              _requiresIdentityReview = true;
              _signedIn = false;
            } else if (error is BackendApiException && error.statusCode == 401) {
              await session.clear();
              _signedIn = false;
            } else {
              _restoreError = error is BackendApiException
                  ? error.message
                  : 'Testagram could not verify the native session. Check your connection and retry.';
              _signedIn = false;
            }
          }
        }
      } on NativeAuthException catch (error) {
        if (error.statusCode == 401 || !await session.hasStoredSession()) {
          await session.clear();
          _signedIn = false;
        } else {
          _restoreError = error.message;
          _signedIn = false;
        }
      } catch (_) {
        _restoreError = 'Testagram could not restore your secure session. Check your connection and retry.';
        _signedIn = false;
      }
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final account = widget.account!;
      final user = await account.get();
      _requiresVerification = !user.emailVerification;
      _signedIn = false;
      if (user.emailVerification) {
        final api = _createApi();
        try {
          await api.getMyProfile();
          _api = api;
          _signedIn = true;
        } catch (error) {
          api.close();
          if (error is BackendApiException &&
              error.statusCode == 403 &&
              (error.code == 'IDENTITY_APPROVAL_REQUIRED' ||
               error.message.toLowerCase().contains('identity review') ||
               error.message.toLowerCase().contains('two-person account approval'))) {
            _requiresIdentityReview = true;
            _restoreError = null;
          } else {
            _restoreError = error is BackendApiException
                ? error.message
                : 'Testagram could not verify your account with the Backend. Check your connection and retry.';
          }
        }
      }
    } catch (_) {
      _signedIn = false;
      _requiresVerification = false;
      _api?.close();
      _api = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  BackendApi _createApi() => BackendApi(
        baseUri: AppConfig.backendOrigin,
        getJwt: () async {
          if (AppConfig.useNativeAuth) {
            return widget.nativeAuthSession!.getAccessToken();
          }
          return (await widget.account!.createJWT()).jwt;
        },
        refreshJwt: AppConfig.useNativeAuth
            ? () => widget.nativeAuthSession!.getAccessToken(forceRefresh: true)
            : null,
      );

  void _onSignedIn() {
    setState(() {
      _signedIn = true;
      _requiresVerification = false;
      _api = _createApi();
    });
  }

  Future<void> _onNativeSignedIn() async {
    final api = _createApi();
    try {
      await api.getMyProfile();
      if (!mounted) {
        api.close();
        return;
      }
      setState(() {
        _signedIn = true;
        _requiresVerification = false;
        _requiresIdentityReview = false;
        _restoreError = null;
        _api = api;
      });
    } catch (_) {
      api.close();
      rethrow;
    }
  }

  Future<void> _signOut() async {
    try {
      if (AppConfig.useNativeAuth) {
        await widget.nativeAuthSession!.signOut();
      } else {
        await widget.account!.deleteSession(sessionId: 'current');
      }
    } finally {
      _api?.close();
      if (mounted) {
        setState(() {
          _signedIn = false;
          _restoreError = null;
          _requiresVerification = false;
          _requiresIdentityReview = false;
          _api = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_restoreError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.link_off_rounded,
                        size: 48, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text('Finishing your secure sign-in',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 10),
                    const Text(
                      AppConfig.useNativeAuth
                          ? 'Your native session is active, but Testagram Backend has not confirmed the canonical account yet. Product access stays locked until the Backend confirms it.'
                          : 'Appwrite has an active session, but Testagram Backend has not confirmed the linked account yet. Your feed and posting stay locked until both checks succeed.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(_restoreError!, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _loading ? null : _restore,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry connection'),
                    ),
                    TextButton(
                      onPressed: _loading ? null : _signOut,
                      child: const Text('Sign out and return to sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (!_signedIn) {
      if (AppConfig.useNativeAuth) {
        return NativeAuthScreen(
          session: widget.nativeAuthSession!,
          onSignedIn: _onNativeSignedIn,
        );
      }
      return AuthScreen(
        account: widget.account!,
        onSignedIn: _onSignedIn,
        requireVerification: _requiresVerification,
        requireIdentityReview: _requiresIdentityReview,
        enableIdentityRegistration: AppConfig.enableIdentityRegistrationUi,
      );
    }
    return MainShell(
      api: _api!,
      onSignOut: _signOut,
      themeMode: widget.themeMode,
      onThemeModeChanged: widget.onThemeModeChanged,
    );
  }
}

class _ConfigurationRequired extends StatelessWidget {
  const _ConfigurationRequired();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hub_rounded, color: Color(0xFF18A957), size: 52),
                const SizedBox(height: 16),
                Text('Testagram', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 10),
                Text(
                  AppConfig.useNativeAuth
                      ? 'This native build needs the Testagram Backend API URL. Configure it with --dart-define before running.'
                      : 'This migration build needs an Appwrite endpoint, Appwrite project ID, and Testagram Backend API URL. Configure them with --dart-define before running.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
}
