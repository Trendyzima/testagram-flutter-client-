import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';

import 'core/app_config.dart';
import 'core/backend_api.dart';
import 'features/auth/auth_screen.dart';
import 'app/main_shell.dart';

class TestagramApp extends StatelessWidget {
  const TestagramApp({super.key, this.account});

  final Account? account;

  static const _green = Color(0xFF18A957);
  static const _ink = Color(0xFF080D0A);

  @override
  Widget build(BuildContext context) {
    final configured = AppConfig.isConfigured && account != null;
    return MaterialApp(
      title: 'Testagram',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _ink,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _green,
          brightness: Brightness.dark,
          surface: const Color(0xFF101713),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _ink,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        useMaterial3: true,
      ),
      home: configured
          ? AuthGate(account: account!)
          : const _ConfigurationRequired(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.account});
  final Account account;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _signedIn = false;
  BackendApi? _api;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      await widget.account.get();
      _signedIn = true;
      _api = _createApi();
    } catch (_) {
      _signedIn = false;
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
      return AuthScreen(account: widget.account, onSignedIn: _onSignedIn);
    }
    return MainShell(api: _api!, onSignOut: _signOut);
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
