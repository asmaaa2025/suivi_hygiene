import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/haccp_user_account.dart';
import '../../../data/repositories/haccp_user_account_repository.dart';
import '../../../shared/utils/navigation_helpers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import 'haccp_user_account_form_page.dart';

/// Page de gestion des comptes utilisateurs HACCPilot (admin only)
/// Distinct du registre du personnel
class HaccpUserAccountsPage extends StatefulWidget {
  const HaccpUserAccountsPage({super.key});

  @override
  State<HaccpUserAccountsPage> createState() => _HaccpUserAccountsPageState();
}

class _HaccpUserAccountsPageState extends State<HaccpUserAccountsPage> {
  final _repo = HaccpUserAccountRepository();
  List<HaccpUserAccount> _accounts = [];
  bool _isLoading = true;
  String? _error;
  final _df = DateFormat('dd/MM/yyyy', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final accounts = await _repo.getAll();
      if (mounted) {
        setState(() {
          _accounts = accounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteAccount(HaccpUserAccount account) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le compte'),
        content: Text(
          'Supprimer l\'enregistrement du compte "${account.email}" ? '
          'Le compte de connexion Supabase n\'est pas supprimé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _repo.delete(account.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Compte retiré de la liste')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comptes HACCPilot'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/rh-hub'),
          tooltip: 'Retour',
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await context.push('/admin/rh/accounts/new');
              if (result == true && mounted) _loadData();
            },
            tooltip: 'Nouveau compte',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ErrorState(message: _error!, onRetry: _loadData)
          : _accounts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const EmptyState(
                      icon: Icons.person_add,
                      title: 'Aucun compte',
                      message:
                          'Les comptes HACCPilot permettent de se connecter à l\'app.\n'
                          'Ils sont distincts du registre du personnel.',
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await context.push(
                          '/admin/rh/accounts/new',
                        );
                        if (result == true && mounted) _loadData();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Créer un compte'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _accounts.length,
                itemBuilder: (context, index) {
                  final a = _accounts[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryBlue.withOpacity(0.2),
                        child: Icon(Icons.person, color: AppTheme.primaryBlue),
                      ),
                      title: Text(
                        a.displayLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.email,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            'Créé le ${_df.format(a.createdAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'delete') _deleteAccount(a);
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Retirer de la liste'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
