import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../data/models/employee.dart';

/// Page to enter admin code for admin employees
class AdminCodePage extends StatefulWidget {
  final Employee? employee;

  const AdminCodePage({super.key, this.employee});

  @override
  State<AdminCodePage> createState() => _AdminCodePageState();
}

/// Wrapper to pass employee
class AdminCodePageWithEmployee extends StatelessWidget {
  final Employee employee;

  const AdminCodePageWithEmployee({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return AdminCodePage(employee: employee);
  }
}

class _AdminCodePageState extends State<AdminCodePage> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
  }

  Employee? get _employee => widget.employee;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _verifyCode() {
    if (!_formKey.currentState!.validate()) return;

    final enteredCode = _codeController.text.trim();
    final correctCode = _employee?.adminCode;

    if (enteredCode == correctCode) {
      // Code is correct, return true
      Navigator.pop(context, true);
    } else {
      // Code is incorrect
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code incorrect'),
          backgroundColor: Colors.red,
        ),
      );
      _codeController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Code administrateur'),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.purple.shade400, Colors.purple.shade600],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Code administrateur',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_employee != null)
                      Text(
                        'Bonjour ${_employee!.firstName}',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Entrez votre code à 4 chiffres',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Card(
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _codeController,
                              decoration: const InputDecoration(
                                labelText: 'Code à 4 chiffres',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.lock),
                                hintText: '0000',
                              ),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 8,
                              ),
                              maxLength: 4,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Veuillez entrer le code';
                                }
                                if (value.length != 4) {
                                  return 'Le code doit contenir 4 chiffres';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _verifyCode(),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _verifyCode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text(
                                  'Valider',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Annuler'),
                            ),
                          ],
                        ),
                      ),
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
