import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;

/// Supabase configuration
/// Loads values from environment variables (.env file)
/// See .env.example for required variables
class SupabaseConfig {
  static String get supabaseUrl {
    if (kDebugMode) {
      // In debug mode, try to load from .env file
      return dotenv.env['SUPABASE_URL'] ??
          'https://your-project.supabase.co'; // Fallback for development
    }
    // In release mode, use environment variable or build-time config
    return const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://your-project.supabase.co',
    );
  }

  static String get supabaseAnonKey {
    if (kDebugMode) {
      return dotenv.env['SUPABASE_ANON_KEY'] ??
          'your-anon-key-here'; // Fallback for development
    }
    return const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'your-anon-key-here',
    );
  }

  // Storage bucket names for photos
  static String get photosBucket {
    try {
      return dotenv.env['SUPABASE_PHOTOS_BUCKET'] ?? 'haccp-photos';
    } catch (e) {
      return 'haccp-photos';
    }
  }

  static String get relevesBucket {
    try {
      return dotenv.env['SUPABASE_RELEVES_BUCKET'] ?? 'releves';
    } catch (e) {
      return 'releves';
    }
  }
}
