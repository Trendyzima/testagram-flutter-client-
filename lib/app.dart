import 'package:appwrite/appwrite.dart';
import 'package:material_ui/material_ui.dart';

import 'core/app_config.dart';
import 'core/backend_api.dart';
import 'core/testagram_theme.dart';
import 'features/auth/auth_screen.dart';
import 'app/main_shell.dart';

class TestagramApp extends StatefulWidget {
  const TestagramApp({super.key, this.account});

  final Account? account;

  @override
  State<TestagramApp> createState() => _TestagramAppState();
}

class _TestagramAppState extends State<TestagramApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    final configured = AppConfig.isConfigured && widget.account != null;
    return MaterialApp(
      title: 'Testagram',
      debugShowCheckedModeBanner: false,
      theme: TestagramTheme.light(),
      darkTheme: TestagramTheme.dark(),
      themeMode: _themeMode,
      home: configured
          ? AuthGate(
              account: widget.account!,
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
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final Account account;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _signedIn = false;
  bool _requiresVerification = false;
  BackendApi? _api;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final user = await widget.account.get();
      _requiresVerification = !user.emailVerification;
      _signedIn = user.emailVerification;
      if (_signedIn) _api = _createApi();
    } catch (_) {
      _signedIn = false;
      _requiresVerification = false;
    }
    if (mounted) setState(() => _loading = false);
  }

  BackendApi _createApi() => BackendApi(
        baseUri: AppConfig.backendOrigin,
        getJwt: () async => (await widget.account.createJWT()).jwt,
      );

  void _onSignedIn() {
    setState(() {
      _signedIn = true;
      _requiresVerification = false;
      _api = _createApi();
    });
  }

  Future<void> _signOut() async {
    try {
      await widget.account.deleteSession(sessionId: 'current');
    } finally {
      _api?.close();
      if (mounted) {
        setState(() {
          _signedIn = false;
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
    if (!_signedIn) {
      return AuthScreen(
        account: widget.account,
        onSignedIn: _onSignedIn,
        requireVerification: _requiresVerification,
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
                const Text(
                  'This build needs an Appwrite endpoint, Appwrite project ID, and Testagram Backend API URL. Configure them with --dart-define before running.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
}
