import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/employee_repository.dart';
import '../../../../data/models/employee.dart';

/// Employee form page (create/edit) - Admin only
class EmployeeFormPage extends StatefulWidget {
  final String? employeeId;

  const EmployeeFormPage({super.key, this.employeeId});

  @override
  State<EmployeeFormPage> createState() => _EmployeeFormPageState();
}

class _EmployeeFormPageState extends State<EmployeeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _roleController = TextEditingController();
  final _adminCodeController = TextEditingController();
  final _adminEmailController = TextEditingController();

  final _employeeRepo = EmployeeRepository();
  bool _isLoading = false;
  bool _isLoadingData = true;
  Employee? _employee;
  bool _isActive = true;
  bool _isAdmin = false;

  Future<bool> _verifyAdminCreation() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null || currentUser.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez être connecté pour créer un admin'),
        ),
      );
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _AdminVerificationDialog(userEmail: currentUser.email!),
    );

    return result ?? false;
  }

  @override
  void initState() {
    super.initState();
    if (widget.employeeId != null) {
      _loadEmployee();
    } else {
      _isLoadingData = false;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _roleController.dispose();
    _adminCodeController.dispose();
    _adminEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployee() async {
    try {
      // Use checkCreatedBy: false to allow editing employees from same organization
      final employee = await _employeeRepo.getById(
        widget.employeeId!,
        checkCreatedBy: false,
      );
      if (employee != null && mounted) {
        setState(() {
          _employee = employee;
          _firstNameController.text = employee.firstName;
          _lastNameController.text = employee.lastName;
          _roleController.text = employee.role;
          _isActive = employee.isActive;
          _isAdmin = employee.isAdmin;
          _adminCodeController.text = employee.adminCode ?? '';
          // Pre-fill email with current user's email if admin
          if (employee.isAdmin) {
            final currentUser = Supabase.instance.client.auth.currentUser;
            _adminEmailController.text = currentUser?.email ?? '';
          }
          _isLoadingData = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoadingData = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Employé introuvable')));
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.employeeId != null) {
        // Update
        // For admin update, verify that current user email exists
        String? adminEmail;
        String? adminCode;

        if (_isAdmin) {
          // Use the email entered by the user
          final enteredEmail = _adminEmailController.text.trim();
          if (enteredEmail.isEmpty) {
            throw Exception('L\'email est requis pour modifier un admin');
          }

          // Verify that the email matches the logged-in user's email
          final currentUser = Supabase.instance.client.auth.currentUser;
          final userEmail = currentUser?.email;
          if (userEmail == null || userEmail.isEmpty) {
            throw Exception('Vous devez être connecté pour modifier un admin');
          }
          if (enteredEmail.toLowerCase() != userEmail.toLowerCase()) {
            throw Exception(
              'L\'email doit correspondre à votre email de connexion',
            );
          }

          adminEmail = enteredEmail; // Required by database constraint

          // Validate admin code
          final trimmedCode = _adminCodeController.text.trim();
          if (trimmedCode.isEmpty || trimmedCode.length != 4) {
            throw Exception(
              'Le code administrateur doit contenir exactement 4 chiffres',
            );
          }
          adminCode = trimmedCode;
        }

        await _employeeRepo.update(
          id: widget.employeeId!,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          role: _roleController.text,
          isActive: _isActive,
          isAdmin: _isAdmin,
          adminCode: adminCode,
          adminEmail: adminEmail,
        );
      } else {
        // Create (organization will be created automatically if needed)
        // For admin creation, verify that current user email exists
        String? adminEmail;
        String? adminCode;

        if (_isAdmin) {
          // Use the email entered by the user
          final enteredEmail = _adminEmailController.text.trim();
          if (enteredEmail.isEmpty) {
            throw Exception('L\'email est requis pour créer un admin');
          }

          // Verify that the email matches the logged-in user's email
          final currentUser = Supabase.instance.client.auth.currentUser;
          final userEmail = currentUser?.email;
          if (userEmail == null || userEmail.isEmpty) {
            throw Exception('Vous devez être connecté pour créer un admin');
          }
          if (enteredEmail.toLowerCase() != userEmail.toLowerCase()) {
            throw Exception(
              'L\'email doit correspondre à votre email de connexion',
            );
          }

          adminEmail = enteredEmail; // Required by database constraint

          // Validate admin code
          final trimmedCode = _adminCodeController.text.trim();
          if (trimmedCode.isEmpty || trimmedCode.length != 4) {
            throw Exception(
              'Le code administrateur doit contenir exactement 4 chiffres',
            );
          }
          adminCode = trimmedCode;
        }

        await _employeeRepo.create(
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          role: _roleController.text,
          isAdmin: _isAdmin,
          adminCode: adminCode,
          adminEmail: adminEmail,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.employeeId != null ? 'Employé modifié' : 'Employé créé',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // If creating first employee, go back to employee selection page
        // Otherwise, just pop to previous page
        if (widget.employeeId == null) {
          // New employee created - go back to employee selection
          // Use a small delay to ensure the navigation completes
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              context.go('/employee-selection');
            }
          });
        } else {
          // Employee updated - just pop
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.employeeId != null ? 'Modifier l\'employé' : 'Nouvel employé',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.employeeId != null) {
              // Si on modifie, retourner à la liste
              context.go('/admin/employees');
            } else {
              // Si on crée, retourner au menu principal
              context.go('/admin/home');
            }
          },
          tooltip: 'Retour',
        ),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'Prénom *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez saisir un prénom';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez saisir un nom';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _roleController,
                    decoration: const InputDecoration(
                      labelText: 'Rôle *',
                      hintText: 'Ex: Manager, Employé, Cuisinier, etc.',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Veuillez saisir un rôle';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Administrateur'),
                    subtitle: const Text('Accès administrateur avec code'),
                    value: _isAdmin,
                    onChanged: (value) async {
                      if (value) {
                        // Verify before enabling admin
                        final verified = await _verifyAdminCreation();
                        if (!verified) {
                          return; // Don't enable if verification failed
                        }
                        // Pre-fill with current user's email
                        final currentUser =
                            Supabase.instance.client.auth.currentUser;
                        final userEmail = currentUser?.email ?? '';
                        _adminEmailController.text = userEmail;
                      }
                      setState(() {
                        _isAdmin = value;
                        if (!value) {
                          _adminCodeController.clear();
                          _adminEmailController.clear();
                        }
                      });
                    },
                    secondary: Icon(
                      _isAdmin ? Icons.admin_panel_settings : Icons.person,
                      color: _isAdmin ? Colors.purple : Colors.grey,
                    ),
                  ),
                  if (_isAdmin) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _adminEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Votre email (pour vérification) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                        helperText:
                            'Saisissez votre email pour confirmer la création d\'un admin',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (_isAdmin) {
                          if (value == null || value.isEmpty) {
                            return 'L\'email est requis';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Veuillez saisir un email valide';
                          }
                          // Verify that the email matches the logged-in user's email
                          final currentUser =
                              Supabase.instance.client.auth.currentUser;
                          final userEmail = currentUser?.email;
                          if (userEmail != null &&
                              value.trim().toLowerCase() !=
                                  userEmail.toLowerCase()) {
                            return 'L\'email doit correspondre à votre email de connexion';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _adminCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Code administrateur (4 chiffres) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                        helperText: 'Code à 4 chiffres pour l\'accès admin',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (_isAdmin) {
                          if (value == null || value.isEmpty) {
                            return 'Le code admin est requis';
                          }
                          if (value.length != 4) {
                            return 'Le code doit contenir 4 chiffres';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                  if (widget.employeeId != null) ...[
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Actif'),
                      value: _isActive,
                      onChanged: (value) {
                        setState(() {
                          _isActive = value ?? true;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primary,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Enregistrer',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Dialog to verify user identity before creating an admin
class _AdminVerificationDialog extends StatefulWidget {
  final String userEmail;

  const _AdminVerificationDialog({required this.userEmail});

  @override
  State<_AdminVerificationDialog> createState() =>
      _AdminVerificationDialogState();
}

class _AdminVerificationDialogState extends State<_AdminVerificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.userEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Verify email matches
      if (email.toLowerCase() != widget.userEmail.toLowerCase()) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'L\'email ne correspond pas à votre compte';
        });
        return;
      }

      // Verify password by attempting to re-authenticate
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Success - close dialog and return true
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on AuthException catch (e) {
      // Handle authentication errors
      String errorMsg = 'Erreur de vérification';
      if (e.message.contains('Invalid login credentials') ||
          e.message.contains('Invalid password') ||
          e.message.contains('Wrong password')) {
        errorMsg = 'Mot de passe incorrect';
      } else if (e.message.contains('Email not confirmed')) {
        errorMsg = 'Email non confirmé';
      } else {
        errorMsg = 'Erreur: ${e.message}';
      }

      setState(() {
        _isLoading = false;
        _errorMessage = errorMsg;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur de vérification: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vérification requise'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pour créer un administrateur, veuillez confirmer votre identité :',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Votre email *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'L\'email est requis';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Email invalide';
                  }
                  if (value.toLowerCase() != widget.userEmail.toLowerCase()) {
                    return 'L\'email doit correspondre à votre compte';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Votre mot de passe *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  errorText: _errorMessage,
                ),
                obscureText: _obscurePassword,
                onChanged: (_) {
                  // Clear error when user starts typing
                  if (_errorMessage != null) {
                    setState(() {
                      _errorMessage = null;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Le mot de passe est requis';
                  }
                  return null;
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
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
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Vérifier'),
        ),
      ],
    );
  }
}
