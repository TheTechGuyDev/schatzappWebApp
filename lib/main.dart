import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'widgets/ui_scale.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
    headers: {'X-Client-Info': 'schatzapp-web'},
  );
  runApp(const SchatzWebApp());
}

class SchatzWebApp extends StatelessWidget {
  const SchatzWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SchatzApp Web',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
      builder: (context, child) => UiScale(child: child!),
    );
  }
}
