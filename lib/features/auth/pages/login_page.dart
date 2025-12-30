import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/friteuse_seed_service.dart';

/// Login page with email/password authentication
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint(
          '[Login] Attempting login for: ${_emailController.text.trim()}');
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      debugPrint('[Login] ✅ Login successful! User: ${response.user?.email}');
      debugPrint(
          '[Login] Session exists: ${Supabase.instance.client.auth.currentSession != null}');

      // Seed default friteuses after login
      try {
        final seedService = FriteuseSeedService();
        await seedService.ensureDefaultFriteuses();
      } catch (e) {
        // Don't block login if seed fails
        debugPrint('[Login] Seed failed: $e');
      }

      if (mounted) {
        debugPrint('[Login] Navigating to /home');
        // Redirect to home page after successful login
        context.go('/home');
        debugPrint('[Login] Navigation called');
      }
    } on AuthException catch (e) {
      debugPrint('[Login] ❌ AuthException: ${e.message}');
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e, stackTrace) {
      debugPrint('[Login] ❌ Error: $e');
      debugPrint('[Login] StackTrace: $stackTrace');
      setState(() {
        _errorMessage = 'Une erreur est survenue. Veuillez réessayer.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 64,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Suivi HACCP',
                      style: Theme.of(context).textTheme.displaySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connectez-vous pour continuer',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre email';
                        }
                        if (!value.contains('@')) {
                          return 'Email invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(Icons.lock_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre mot de passe';
                        }
                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.statusCriticalBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: AppTheme.statusCritical, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style:
                                    TextStyle(color: AppTheme.statusCritical),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Se connecter'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
