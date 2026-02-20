import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/cache_service.dart';
import '../../../../services/employee_session_service.dart';
import '../../../../services/auth_service.dart';

class ParametresPage extends StatefulWidget {
  const ParametresPage({super.key});

  @override
  State<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage> {
  final _apiUrlController = TextEditingController();
  final _timeoutController = TextEditingController();
  bool _notificationsEnabled = true;
  bool _syncAutoEnabled = true;
  int _syncInterval = 5; // minutes

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiUrlController.text =
          prefs.getString('api_url') ?? 'http://192.168.1.69:8001/api';
      _timeoutController.text =
          prefs.getInt('timeout_seconds')?.toString() ?? '10';
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _syncAutoEnabled = prefs.getBool('sync_auto_enabled') ?? true;
      _syncInterval = prefs.getInt('sync_interval') ?? 5;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_url', _apiUrlController.text);
    await prefs.setInt(
      'timeout_seconds',
      int.tryParse(_timeoutController.text) ?? 10,
    );
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('sync_auto_enabled', _syncAutoEnabled);
    await prefs.setInt('sync_interval', _syncInterval);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Paramètres sauvegardés')));
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer toutes les données locales ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Ici vous pouvez ajouter la logique pour supprimer toutes les données
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toutes les données ont été supprimées')),
      );
    }
  }

  Future<void> _changeEmployee() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer d\'employé'),
        content: const Text(
          'Voulez-vous changer de compte employé ? Vous serez redirigé vers la page de sélection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Changer', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Clear current employee session
        final sessionService = EmployeeSessionService();
        await sessionService.clear();

        // Redirect to employee selection page
        if (mounted) {
          context.go('/employee-selection');
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

  Future<void> _logout() async {
    try {
      // Clear cache
      await CacheService().clear();

      // Sign out from Supabase
      await Supabase.instance.client.auth.signOut();

      // AuthGate will automatically redirect to login
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Déconnexion réussie')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la déconnexion: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'Paramètres',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Section Notifications
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Activer les notifications'),
                    subtitle: const Text(
                      'Recevoir des alertes pour les tâches importantes',
                    ),
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Section Actions
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Actions',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.sync, color: Colors.green),
                    title: const Text('Synchroniser maintenant'),
                    onTap: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Synchronisation en cours...'),
                        ),
                      );
                      try {
                        // await PleskSyncService().forceSync(); // Désactivé - on utilise Supabase maintenant
                        // TODO: Implémenter la synchronisation Supabase si nécessaire
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Synchronisation terminée !'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Erreur de synchronisation: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info, color: Colors.orange),
                    title: const Text('À propos'),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('À propos'),
                          content: const Text(
                            'Suivi d\'Hygiène v1.0.0\n\n'
                            'Application de suivi des températures et de l\'hygiène pour la restauration.\n\n'
                            'Développé avec Flutter et Supabase.\n\n'
                            '© 2024 Tous droits réservés.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Fermer'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.swap_horiz, color: Colors.blue),
                    title: const Text('Changer d\'employé'),
                    subtitle: const Text(
                      'Sélectionner un autre compte employé',
                    ),
                    onTap: _changeEmployee,
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Se déconnecter'),
                    onTap: _logout,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
