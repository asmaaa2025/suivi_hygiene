import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase service with single client instance
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  /// Get the Supabase client (must be initialized in main.dart)
  SupabaseClient get client {
    final client = Supabase.instance.client;
    return client;
  }

  /// Get current user ID (throws if not authenticated)
  String get currentUserId {
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.id;
  }

  /// Check if user is authenticated
  bool get isAuthenticated => client.auth.currentUser != null;

  /// Get current user email
  String? get currentUserEmail => client.auth.currentUser?.email;

  /// Stream of auth state changes
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;
}
