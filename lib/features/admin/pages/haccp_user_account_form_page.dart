import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/haccp_user_account_repository.dart';
import '../../../data/repositories/personnel_repository.dart';

/// Formulaire pour créer un compte utilisateur HACCPilot
class HaccpUserAccountFormPage extends StatefulWidget {
  const HaccpUserAccountFormPage({super.key});

  @override
  State<HaccpUserAccountFormPage> createState() => _HaccpUserAccountFormPageState();
}

class _HaccpUserAccountFormPageState extends State<HaccpUserAccountFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _repo = HaccpUserAccountRepository();
  final _personnelRepo = PersonnelRepository();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _selectedPersonnelId;
  List<Map<String, String>> _personnelOptions = [];

  @override
  void initState() {
    super.initState();
    _loadPersonnel();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPersonnel() async {
    try {
      final list = await _personnelRepo.getAll(activeOnly: true);
      if (mounted) {
        setState(() {
          _personnelOptions = list
              .map((p) => {'id': p.id, 'label': '${p.fullName} (${p.contractType.displayName})'})
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _repo.create(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _displayNameController.text.trim().isEmpty ? null : _displayNameController.text.trim(),
        personnelId: _selectedPersonnelId?.isEmpty == true ? null : _selectedPersonnelId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compte créé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau compte HACCPilot'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: 'Retour',
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compte de connexion à l\'app',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ces comptes sont distincts du registre du personnel. '
                      'Ils permettent de se connecter à HACCPilot.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email *',
                hintText: 'exemple@entreprise.fr',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email requis';
                if (!v.contains('@') || !v.contains('.')) return 'Email invalide';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Mot de passe *',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: const OutlineInputBorder(),
              ),
              obscureText: _obscurePassword,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Mot de passe requis';
                if (v.length < 6) return 'Minimum 6 caractères';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Nom d\'affichage (optionnel)',
                hintText: 'Ex: Jean Dupont',
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_personnelOptions.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                value: _selectedPersonnelId,
                decoration: const InputDecoration(
                  labelText: 'Lier au registre personnel (optionnel)',
                  prefixIcon: Icon(Icons.people),
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Aucun')),
                  ..._personnelOptions.map((p) => DropdownMenuItem(value: p['id'], child: Text(p['label']!))),
                ],
                onChanged: (v) => setState(() => _selectedPersonnelId = v),
              ),
              const SizedBox(height: 8),
              Text(
                'Lier ce compte à une fiche du registre personnel',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
            ] else
              const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Créer le compte'),
            ),
          ],
        ),
      ),
    );
  }
}
