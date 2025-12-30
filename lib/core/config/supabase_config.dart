import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get supabaseUrl {
    final v = dotenv.maybeGet('SUPABASE_URL') ?? const String.fromEnvironment('SUPABASE_URL');
    if (v.isEmpty) {
      throw StateError('Missing SUPABASE_URL. Add it to .env or pass --dart-define=SUPABASE_URL=...');
    }
    return v;
  }

  static String get supabaseAnonKey {
    final v = dotenv.maybeGet('SUPABASE_ANON_KEY') ?? const String.fromEnvironment('SUPABASE_ANON_KEY');
    if (v.isEmpty) {
      throw StateError('Missing SUPABASE_ANON_KEY. Add it to .env or pass --dart-define=SUPABASE_ANON_KEY=...');
    }
    return v;
  }

  static String get photosBucket {
    final v = dotenv.maybeGet('SUPABASE_PHOTOS_BUCKET') ??
        const String.fromEnvironment('SUPABASE_PHOTOS_BUCKET', defaultValue: 'haccp-photos');
    return v.isEmpty ? 'haccp-photos' : v;
  }

  static String get relevesBucket {
    final v = dotenv.maybeGet('SUPABASE_RELEVES_BUCKET') ??
        const String.fromEnvironment('SUPABASE_RELEVES_BUCKET', defaultValue: 'releves');
    return v.isEmpty ? 'releves' : v;
  }
}
