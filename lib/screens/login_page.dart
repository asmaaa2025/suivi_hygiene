import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false; // Basculer entre login et signup
  String _errorMessage = '';
  bool _showSuccessMessage = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Méthode utilitaire pour afficher un message d'erreur
  void _showError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
        _showSuccessMessage = false;
      });
    }
  }

  /// Méthode utilitaire pour afficher un message de succès
  void _showSuccess(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = '';
        _showSuccessMessage = true;
      });

      // Masquer le message de succès après 3 secondes
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showSuccessMessage = false;
          });
        }
      });
    }
  }

  /// Méthode utilitaire pour effacer tous les messages
  void _clearMessages() {
    if (mounted) {
      setState(() {
        _errorMessage = '';
        _showSuccessMessage = false;
      });
    }
  }

  /// Gère les erreurs structurées selon leur type
  void _handleStructuredError(Map<String, dynamic> errorResult) {
    final String errorMessage =
        errorResult['error'] ?? 'Erreur de connexion inconnue';
    final String errorType = errorResult['errorType'] ?? 'UNKNOWN_ERROR';
    final int? statusCode = errorResult['statusCode'];

    String displayMessage = errorMessage;
    Color? errorColor = Colors.red.shade700;

    // Personnaliser le message selon le type d'erreur
    switch (errorType) {
      case 'NETWORK_ERROR':
        displayMessage = '🌐 $errorMessage\nVérifiez votre connexion internet.';
        break;

      case 'TIMEOUT_ERROR':
        displayMessage =
            '⏰ $errorMessage\nLe serveur met trop de temps à répondre.';
        break;

      case 'CLIENT_ERROR':
        if (statusCode == 401) {
          displayMessage = '🔐 $errorMessage\nVérifiez vos identifiants.';
        } else if (statusCode == 403) {
          displayMessage = '🚫 $errorMessage\nContactez l\'administrateur.';
        } else if (statusCode == 429) {
          displayMessage =
              '⏳ $errorMessage\nAttendez quelques minutes avant de réessayer.';
        } else {
          displayMessage = '❌ $errorMessage';
        }
        break;

      case 'SERVER_ERROR':
        displayMessage = '🔧 $errorMessage\nLe problème vient du serveur.';
        errorColor = Colors.orange.shade700;
        break;

      case 'FORMAT_ERROR':
        displayMessage =
            '📄 $errorMessage\nProblème de communication avec le serveur.';
        break;

      case 'SAVE_ERROR':
        displayMessage = '💾 $errorMessage\nProblème de sauvegarde locale.';
        break;

      default:
        displayMessage = '❓ $errorMessage';
        break;
    }

    _showError(displayMessage);
  }

  /// Fonction de connexion refactorisée avec gestion d'erreur robuste
  ///
  /// Cette fonction :
  /// 1. Valide le formulaire avant de procéder
  /// 2. Active le spinner de chargement
  /// 3. Appelle l'API avec timeout et gestion d'erreur
  /// 4. Gère tous les cas d'erreur possibles
  /// 5. Arrête le spinner dans tous les cas (succès ou échec)
  /// 6. Affiche des messages d'erreur appropriés à l'utilisateur
  Future<void> _login() async {
    // 1. Validation du formulaire - arrêt si invalide
    if (!_formKey.currentState!.validate()) {
      print('❌ Formulaire invalide, connexion annulée');
      return;
    }

    // 2. Activation du spinner et nettoyage des messages précédents
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
      _clearMessages(); // Effacer tous les messages précédents
    }

    try {
      debugPrint(
        '[AUTH] Attempting login with email: ${_usernameController.text}',
      );

      // 3. Login with Supabase - use signInWithPassword
      final response = await Supabase.instance.client.auth
          .signInWithPassword(
            email: _usernameController.text.trim(),
            password: _passwordController.text,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'Connexion timeout. Vérifiez votre réseau.',
              );
            },
          );

      // Log EVERYTHING
      debugPrint('[AUTH] session=${response.session}');
      debugPrint('[AUTH] user=${response.user}');
      debugPrint('[AUTH] user.id=${response.user?.id}');
      debugPrint('[AUTH] user.email=${response.user?.email}');
      final token = response.session?.accessToken;
      debugPrint(
        '[AUTH] session.accessToken=${token != null ? token.substring(0, 20) : "null"}...',
      );

      // 4. Check if login was successful
      if (response.session != null && response.user != null) {
        debugPrint('[AUTH] ✅ Login successful');
        _showSuccess('Connexion réussie !');

        // Attendre un court délai pour afficher le message de succès
        await Future.delayed(const Duration(milliseconds: 500));

        // Rediriger vers la page d'accueil
        if (mounted) {
          debugPrint('[AUTH] Redirecting to /home');
          context.go('/home'); // Redirect to original dashboard
        }
      } else {
        debugPrint('[AUTH] ❌ Login failed: session or user is null');
        _showError('Échec de la connexion. Vérifiez vos identifiants.');
      }
    } on AuthException catch (e) {
      // Supabase auth errors
      debugPrint('[AUTH][ERROR] ${e.message}');
      debugPrint('[AUTH][STATUS] ${e.statusCode}');
      String errorMessage = 'Erreur de connexion';
      final message = e.message.toLowerCase();
      if (message.contains('invalid login credentials') ||
          message.contains('invalid credentials')) {
        errorMessage =
            'Identifiants incorrects. Vérifiez votre email et mot de passe.';
      } else if (message.contains('email not confirmed') ||
          message.contains('email_not_confirmed')) {
        errorMessage = 'Email non confirmé. Vérifiez votre boîte mail.';
      } else {
        errorMessage = e.message;
      }
      _showError(errorMessage);
    } on TimeoutException catch (e) {
      debugPrint('[AUTH][ERROR] Timeout: $e');
      _showError('Connexion timeout. Vérifiez votre réseau.');
    } catch (e) {
      debugPrint('[AUTH][ERROR] Unexpected error: $e');
      debugPrint('[AUTH][ERROR] Type: ${e.runtimeType}');
      _showError('Erreur inattendue: ${e.toString()}');
    } finally {
      // 8. ARRÊT GARANTI DU SPINNER - dans tous les cas (succès ou échec)
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('🔄 Spinner arrêté');
      }
    }
  }

  /// Fonction d'inscription avec gestion d'erreur robuste
  Future<void> _signUp() async {
    // 1. Validation du formulaire
    if (!_formKey.currentState!.validate()) {
      print('❌ Formulaire invalide, inscription annulée');
      return;
    }

    // 2. Vérifier que les mots de passe correspondent
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Les mots de passe ne correspondent pas.');
      return;
    }

    // 3. Activation du spinner
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
      _clearMessages();
    }

    try {
      debugPrint(
        '[AUTH] Attempting sign up with email: ${_usernameController.text}',
      );

      // Sign up with Supabase - use signUp
      final response = await Supabase.instance.client.auth
          .signUp(
            email: _usernameController.text.trim(),
            password: _passwordController.text,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'Inscription timeout. Vérifiez votre réseau.',
              );
            },
          );

      // Log EVERYTHING
      debugPrint('[AUTH] session=${response.session}');
      debugPrint('[AUTH] user=${response.user}');
      debugPrint('[AUTH] user.id=${response.user?.id}');
      debugPrint('[AUTH] user.email=${response.user?.email}');
      debugPrint(
        '[AUTH] user.emailConfirmedAt=${response.user?.emailConfirmedAt}',
      );

      // Handle email confirmation explicitly
      if (response.user != null) {
        if (response.session != null) {
          // User is automatically signed in (email confirmation disabled in Supabase)
          debugPrint('[AUTH] ✅ Sign up successful, user auto-signed in');
          _showSuccess('Compte créé avec succès !');
          // AuthGate will automatically redirect
        } else {
          // User needs to confirm email
          debugPrint(
            '[AUTH] ⚠️ Sign up successful but email confirmation required',
          );
          _showSuccess(
            'Compte créé ! Veuillez confirmer votre email avant de vous connecter.',
          );
          await Future.delayed(const Duration(milliseconds: 2000));
          if (mounted) {
            setState(() {
              _isSignUp = false;
              _passwordController.clear();
              _confirmPasswordController.clear();
            });
          }
        }
      } else {
        debugPrint('[AUTH] ❌ Sign up failed: user is null');
        _showError('Échec de l\'inscription. Veuillez réessayer.');
      }
    } on AuthException catch (e) {
      // Supabase auth errors
      debugPrint('[AUTH][ERROR] ${e.message}');
      debugPrint('[AUTH][STATUS] ${e.statusCode}');
      String errorMessage = 'Erreur d\'inscription';
      final message = e.message.toLowerCase();
      if (message.contains('user already registered') ||
          message.contains('already registered')) {
        errorMessage = 'Cet email est déjà enregistré. Connectez-vous.';
      } else if (message.contains('password')) {
        errorMessage = 'Le mot de passe ne respecte pas les critères requis.';
      } else {
        errorMessage = e.message;
      }
      _showError(errorMessage);
    } on TimeoutException catch (e) {
      debugPrint('[AUTH][ERROR] Timeout: $e');
      _showError('Inscription timeout. Vérifiez votre réseau.');
    } catch (e) {
      debugPrint('[AUTH][ERROR] Unexpected error: $e');
      debugPrint('[AUTH][ERROR] Type: ${e.runtimeType}');
      _showError('Erreur inattendue: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('🔄 Spinner arrêté');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset:
          true, // Permet au clavier de redimensionner la page
      appBar: AppBar(
        title: Text(_isSignUp ? 'Inscription' : 'Connexion'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.thermostat, size: 80, color: Colors.blue),
              const SizedBox(height: 32),
              Text(
                _isSignUp ? 'Créer un compte' : 'Suivi d\'Hygiène',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _usernameController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: _isSignUp ? 'Email' : 'Email',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un email';
                  }
                  if (!value.contains('@')) {
                    return 'Veuillez entrer un email valide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un mot de passe';
                  }
                  if (_isSignUp && value.length < 6) {
                    return 'Le mot de passe doit contenir au moins 6 caractères';
                  }
                  return null;
                },
              ),
              // Champ de confirmation de mot de passe (uniquement en mode signup)
              if (_isSignUp) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le mot de passe',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez confirmer le mot de passe';
                    }
                    if (value != _passwordController.text) {
                      return 'Les mots de passe ne correspondent pas';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 24),

              // 1. AFFICHAGE DES MESSAGES D'ÉTAT - Erreur et succès avec animation

              // Message d'erreur
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _errorMessage.isNotEmpty ? null : 0,
                child: _errorMessage.isNotEmpty
                    ? Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // Bouton pour fermer l'erreur
                            IconButton(
                              onPressed: () {
                                _clearMessages();
                              },
                              icon: Icon(
                                Icons.close,
                                color: Colors.red.shade700,
                                size: 18,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Message de succès
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _showSuccessMessage ? null : 0,
                child: _showSuccessMessage
                    ? Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          border: Border.all(color: Colors.green.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.green.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Connexion réussie ! Redirection...',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // Indicateur de chargement pour la redirection
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // DEBUG: Print auth state (DEV ONLY)
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    final client = Supabase.instance.client;
                    final session = client.auth.currentSession;
                    final user = client.auth.currentUser;
                    debugPrint('=== AUTH STATE DEBUG ===');
                    debugPrint(
                      'currentSession: ${session != null ? "exists" : "null"}',
                    );
                    if (session != null) {
                      debugPrint(
                        '  - accessToken: ${session.accessToken.substring(0, 20) ?? "null"}...',
                      );
                      debugPrint(
                        '  - refreshToken: ${session.refreshToken?.substring(0, 20) ?? "null"}...',
                      );
                      debugPrint('  - expiresAt: ${session.expiresAt}');
                      debugPrint('  - expiresIn: ${session.expiresIn}');
                    }
                    debugPrint(
                      'currentUser: ${user != null ? "exists" : "null"}',
                    );
                    if (user != null) {
                      debugPrint('  - id: ${user.id}');
                      debugPrint('  - email: ${user.email}');
                      debugPrint(
                        '  - emailConfirmedAt: ${user.emailConfirmedAt}',
                      );
                      debugPrint('  - createdAt: ${user.createdAt}');
                    }
                    debugPrint('=======================');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Auth state logged to console'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: Icon(Icons.bug_report, size: 16),
                  label: Text('Print Auth State (Debug)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                  ),
                ),
              ],

              // 2. BOUTON DE CONNEXION/INSCRIPTION - Amélioré avec meilleur feedback visuel
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  // 3. DÉSACTIVATION DU BOUTON PENDANT LE CHARGEMENT
                  onPressed: _isLoading ? null : (_isSignUp ? _signUp : _login),

                  // 4. STYLE CONDITIONNEL SELON L'ÉTAT
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isLoading
                        ? Colors.grey.shade300
                        : Colors.blue,
                    foregroundColor: _isLoading
                        ? Colors.grey.shade600
                        : Colors.white,
                    elevation: _isLoading ? 0 : 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),

                  // 5. CONTENU DU BOUTON - Spinner ou texte
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Spinner personnalisé
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey.shade600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _isSignUp ? 'Création...' : 'Connexion...',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _isSignUp ? 'Créer le compte' : 'Se connecter',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Bouton pour basculer entre login et signup
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _isSignUp = !_isSignUp;
                          _errorMessage = '';
                          _showSuccessMessage = false;
                          _passwordController.clear();
                          _confirmPasswordController.clear();
                        });
                      },
                child: Text(
                  _isSignUp
                      ? 'Déjà un compte ? Se connecter'
                      : 'Pas de compte ? Créer un compte',
                  style: const TextStyle(fontSize: 14, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
