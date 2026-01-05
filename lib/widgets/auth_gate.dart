import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/pages/login_page.dart';

/// AuthGate: Redirects to login if no session, otherwise shows app
/// Uses Supabase auth.onAuthStateChange to automatically rebuild when auth state changes
/// DO NOT use Navigator.push for auth routing - this widget handles it automatically
class AuthGate extends StatefulWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _hasCheckedInitialSession = false;

  @override
  void initState() {
    super.initState();
    // Force logout on first app start to always show login page first
    _checkAndClearSession();
  }

  Future<void> _checkAndClearSession() async {
    if (!_hasCheckedInitialSession) {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;

      if (session != null) {
        debugPrint('[AuthGate] Clearing existing session on app start...');
        await client.auth.signOut();
        debugPrint('[AuthGate] Session cleared, will show login page');
      }

      if (mounted) {
        setState(() {
          _hasCheckedInitialSession = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    // Use StreamBuilder to listen to auth state changes
    // This will automatically rebuild when login/logout happens
    // The stream emits events when auth state changes (login, logout, token refresh, etc.)
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Always check currentSession directly (most up-to-date)
        // The stream may have a slight delay, so we use currentSession as source of truth
        final session = client.auth.currentSession;
        final user = client.auth.currentUser;

        // Log auth state changes for debugging
        if (snapshot.hasData) {
          final authState = snapshot.data;
          debugPrint('[AuthGate] Auth state event: ${authState?.event}');
          debugPrint(
              '[AuthGate] Stream session: ${authState?.session != null ? "exists" : "null"}');
        }

        debugPrint(
            '[AuthGate] Current session: ${session != null ? "exists" : "null"}');
        debugPrint('[AuthGate] Current user: ${user?.email ?? "null"}');

        // Check if session exists and is valid (not expired)
        bool hasValidSession = false;
        if (session != null && user != null) {
          // Check if session is expired
          final expiresAt = session.expiresAt;
          if (expiresAt != null) {
            final now = DateTime.now().toUtc();
            final expiryTime = DateTime.fromMillisecondsSinceEpoch(
                expiresAt * 1000,
                isUtc: true);
            hasValidSession = expiryTime.isAfter(now);
            debugPrint('[AuthGate] Session expires at: $expiryTime');
            debugPrint('[AuthGate] Current time: $now');
            debugPrint('[AuthGate] Session is valid: $hasValidSession');

            if (!hasValidSession) {
              debugPrint('[AuthGate] Session expired, signing out...');
              // Session expired, sign out
              client.auth.signOut();
            }
          } else {
            // No expiry info, assume valid if session exists
            hasValidSession = true;
          }
        }

        // If no valid session or user, show login page
        // AuthGate will automatically rebuild when session changes (via stream)
        if (!hasValidSession || session == null || user == null) {
          debugPrint('[AuthGate] → Showing LoginPage (no valid session)');
          return const LoginPage();
        }

        // If valid session exists, show the app (dashboard)
        // No manual navigation needed - AuthGate rebuilds automatically
        debugPrint('[AuthGate] → Showing Dashboard (valid session exists)');
        return widget.child;
      },
    );
  }
}
