import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/friteuse_seed_service.dart';
import 'login_reset_password_dialogs.dart';

/// Page de connexion avec authentification email/mot de passe.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const int _otpResendCooldownSeconds = 60;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  int _passwordFieldVersion = 0;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _nextResetRequestAt;
  String? _resetCooldownEmail;

  Future<void> _handleLogin() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final email = _email.trim();
    final password = _password;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('[Connexion] Tentative pour: $email');
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      debugPrint('[Connexion] ✅ Connexion réussie. Utilisateur: ${response.user?.email}');
      debugPrint(
        '[Connexion] Session active: ${Supabase.instance.client.auth.currentSession != null}',
      );

      try {
        final seedService = FriteuseSeedService();
        await seedService.ensureDefaultFriteuses();
      } catch (e) {
        debugPrint('[Connexion] Initialisation des friteuses échouée: $e');
      }

      if (!mounted) return;
      debugPrint('[Connexion] Navigation vers /home');
      context.go('/home');
      debugPrint('[Connexion] Navigation effectuée');
    } on AuthException catch (e) {
      debugPrint('[Connexion] ❌ Erreur auth: ${e.message}');
      if (!mounted) return;
      setState(() {
        _errorMessage = _toFrenchAuthError(e.message);
      });
    } catch (e, stackTrace) {
      debugPrint('[Connexion] ❌ Erreur: $e');
      debugPrint('[Connexion] StackTrace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Une erreur est survenue. Veuillez réessayer.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final initialEmail = _email.trim();
    final useCooldownForEmail =
        _resetCooldownEmail != null &&
        _resetCooldownEmail!.toLowerCase() == initialEmail.toLowerCase();

    final result = await showDialog<ForgotPasswordEmailResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ForgotPasswordEmailDialog(
        initialEmail: initialEmail,
        cooldownUntil: useCooldownForEmail ? _nextResetRequestAt : null,
        cooldownSeconds: _otpResendCooldownSeconds,
      ),
    );
    if (result == null || !mounted) return;
    _nextResetRequestAt = result.cooldownUntil;
    _resetCooldownEmail = result.email.trim().toLowerCase();
    final email = result.email.trim();
    if (email.isEmpty || !email.contains('@')) return;
    await _showOtpResetDialog(email);
  }

  Future<void> _showOtpResetDialog(String email) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OtpResetPasswordDialog(
        email: email,
        cooldownSeconds: _otpResendCooldownSeconds,
      ),
    );
    if (!mounted || ok != true) return;
    setState(() {
      _password = '';
      _passwordFieldVersion++;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mot de passe réinitialisé avec succès.'),
        backgroundColor: Colors.green,
      ),
    );
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
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          onChanged: (value) => _email = value.trim(),
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
                          key: ValueKey('pwd_$_passwordFieldVersion'),
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: Icon(Icons.lock_outlined),
                          ),
                          onChanged: (value) => _password = value,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer votre mot de passe';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed:
                                _isLoading ? null : _showForgotPasswordDialog,
                            child: const Text('Mot de passe oublié ?'),
                          ),
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
                                Icon(
                                  Icons.error_outline,
                                  color: AppTheme.statusCritical,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: AppTheme.statusCritical,
                                    ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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

String _toFrenchAuthError(String raw) {
  final msg = raw.toLowerCase();
  if (msg.contains('invalid login credentials') ||
      msg.contains('invalid credentials')) {
    return 'Identifiants invalides. Vérifiez votre email et votre mot de passe.';
  }
  if (msg.contains('email not confirmed') ||
      msg.contains('email_not_confirmed')) {
    return 'Email non confirmé. Vérifiez votre boîte mail.';
  }
  if (msg.contains('rate limit')) {
    return 'Trop de tentatives. Patientez environ 60 secondes puis réessayez.';
  }
  if (msg.contains('network') || msg.contains('socket')) {
    return 'Erreur réseau. Vérifiez votre connexion internet.';
  }
  return 'Une erreur est survenue. Vérifiez les informations puis réessayez.';
}
