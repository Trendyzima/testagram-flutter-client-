import 'package:material_ui/material_ui.dart';

import 'core/app_config.dart';
import 'core/auth/native_auth_client.dart';
import 'core/backend_api.dart';
import 'core/testagram_theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/settings/email_notification_settings_screen.dart';
import 'app/main_shell.dart';

class TestagramApp extends StatefulWidget {
  const TestagramApp({super.key, this.authClient});

  final NativeAuthClient? authClient;

  @override
  State<TestagramApp> createState() => _TestagramAppState();
}

class _TestagramAppState extends State<TestagramApp> {
  ThemeMode _themeMode = ThemeMode.system;
  late final NativeAuthClient _authClient =
      widget.authClient ?? NativeAuthClient(baseUri: AppConfig.backendOrigin);

  @override
  void dispose() {
    if (widget.authClient == null) _authClient.close();
    super.dispose();
  }

  String get _initialDeepLink =>
      WidgetsBinding.instance.platformDispatcher.defaultRouteName;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Testagram',
      debugShowCheckedModeBanner: false,
      theme: TestagramTheme.light(),
      darkTheme: TestagramTheme.dark(),
      themeMode: _themeMode,
      home: AppConfig.isConfigured
          ? AuthGate(
              authClient: _authClient,
              initialDeepLink: _initialDeepLink,
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
    required this.authClient,
    this.initialDeepLink = '/',
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final NativeAuthSession authClient;
  final String initialDeepLink;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _signedIn = false;
  String? _restoreError;
  BackendApi? _api;
  bool _consentPromptChecked = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  BackendApi _createApi() => BackendApi(
        baseUri: AppConfig.backendOrigin,
        getAccessToken: widget.authClient.accessToken,
      );

  Future<void> _restore() async {
    if (mounted) setState(() => _loading = true);
    _restoreError = null;
    try {
      final token = await widget.authClient.accessToken();
      if (token != null && token.isNotEmpty) {
        final api = _createApi();
        try {
          await api.getMyProfile();
          _api = api;
          _signedIn = true;
        } catch (error) {
          api.close();
          _signedIn = false;
          _restoreError = error is BackendApiException
              ? error.message
              : 'Testagram could not validate your saved session. Check your connection and retry.';
        }
      } else {
        _signedIn = false;
      }
    } catch (error) {
      _signedIn = false;
      _restoreError = error is NativeAuthException
          ? error.message
          : 'Testagram could not restore your secure session. Sign in again.';
    }
    if (mounted) {
      setState(() => _loading = false);
      if (_signedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptSocialEmailConsent());
      }
    }
  }

  void _onSignedIn() {
    _consentPromptChecked = false;
    _api?.close();
    setState(() {
      _api = _createApi();
      _signedIn = true;
      _restoreError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptSocialEmailConsent());
  }

  Future<void> _maybePromptSocialEmailConsent() async {
    final api = _api;
    if (!mounted || !_signedIn || api == null || _consentPromptChecked) return;
    _consentPromptChecked = true;
    try {
      final response = await api.getMyEmailNotificationPreferences();
      final value = response['data'];
      final data = value is Map ? Map<String, dynamic>.from(value) : response;
      if (!mounted || data['consent_prompt_required'] != true) return;
      final chooseSettings = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Choose your email updates'),
          content: const Text(
            'Would you like Testagram to email you when someone follows you '
            'or when people you follow share a new post? These updates are '
            'optional. Nothing is emailed until you choose the categories '
            'and save your consent.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Choose settings'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (chooseSettings == true) {
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => EmailNotificationSettingsScreen(
            api: api,
            skipInitialPrompt: true,
          ),
        ));
      } else if (chooseSettings == false) {
        await api.updateMyEmailNotificationPreferences(
          newFollowerEmailEnabled: false,
          newPostEmailEnabled: false,
        );
      }
    } catch (_) {
      // Keep social email disabled if the consent state cannot be read or saved.
      _consentPromptChecked = false;
    }
  }

  Future<void> _signOut() async {
    try {
      await widget.authClient.signOut();
    } catch (error) {
      if (mounted) {
        final message = error is NativeAuthException
            ? error.message
            : 'Testagram could not confirm sign-out. Check your connection and retry.';
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      // Keep the authenticated shell and its secure refresh credential so the
      // user can retry server-side revocation when connectivity returns.
      return;
    }
    _api?.close();
    if (mounted) {
      setState(() {
        _signedIn = false;
        _consentPromptChecked = false;
        _restoreError = null;
        _api = null;
      });
    }
  }

  @override
  void dispose() {
    _api?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_restoreError != null && !_signedIn) {
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
                    Text('Restoring your secure sign-in',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 10),
                    const Text(
                      'Your saved Testagram session could not be confirmed. Your feed and posting remain locked until the Backend validates the session.',
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
                      child: const Text('Clear session and return to sign in'),
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
      return AuthScreen(
        authClient: widget.authClient,
        onSignedIn: _onSignedIn,
        enableIdentityRegistration: AppConfig.enableIdentityRegistrationUi,
      );
    }
    return MainShell(
      api: _api!,
      initialDeepLink: widget.initialDeepLink,
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
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.settings_suggest_outlined, size: 48),
                  SizedBox(height: 16),
                  Text('Testagram needs a valid HTTPS Backend URL and site URL before it can start.'),
                ],
              ),
            ),
          ),
        ),
      );
}
