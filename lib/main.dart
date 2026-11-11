import 'package:appwrite/appwrite.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isConfigured) {
    runApp(const TestagramApp());
    return;
  }

  final client = Client()
    ..setEndpoint(AppConfig.appwriteEndpoint)
    ..setProject(AppConfig.appwriteProjectId);

  final account = Account(client);
  runApp(TestagramApp(account: account));
}
