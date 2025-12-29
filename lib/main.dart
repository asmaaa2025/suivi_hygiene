import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file (if exists)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // .env file is optional - will use defaults or build-time environment variables
    debugPrint(
        'Note: .env file not found. Using defaults or build-time environment variables.');
  }

  // Initialize date formatting for French locale
  await initializeDateFormatting('fr_FR', null);

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: HaccpApp(),
    ),
  );
}

class HaccpApp extends StatelessWidget {
  const HaccpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Suivi HACCP',
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
