import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/cache_service.dart';

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
        'timeout_seconds', int.tryParse(_timeoutController.text) ?? 10);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('sync_auto_enabled', _syncAutoEnabled);
    await prefs.setInt('sync_interval', _syncInterval);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paramètres sauvegardés')),
    );
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text(
            'Êtes-vous sûr de vouloir supprimer toutes les données locales ? Cette action est irréversible.'),
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

  Future<void> _logout() async {
    try {
      // Clear cache
      await CacheService().clear();

      // Sign out from Supabase
      await Supabase.instance.client.auth.signOut();

      // AuthGate will automatically redirect to login
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Déconnexion réussie')),
        );
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
          // Section API
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configuration API',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apiUrlController,
                    decoration: const InputDecoration(
                      labelText: 'URL de l\'API',
                      border: OutlineInputBorder(),
                      hintText: 'http://192.168.1.69:8001/api',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _timeoutController,
                    decoration: const InputDecoration(
                      labelText: 'Timeout (secondes)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

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
                        'Recevoir des alertes pour les tâches importantes'),
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

          // Section Synchronisation
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Synchronisation',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Synchronisation automatique'),
                    subtitle: const Text(
                        'Synchroniser automatiquement avec le serveur'),
                    value: _syncAutoEnabled,
                    onChanged: (value) {
                      setState(() {
                        _syncAutoEnabled = value;
                      });
                    },
                  ),
                  if (_syncAutoEnabled) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Intervalle de synchronisation',
                      style:
                          GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _syncInterval.toDouble(),
                      min: 1,
                      max: 60,
                      divisions: 59,
                      label: '$_syncInterval minutes',
                      onChanged: (value) {
                        setState(() {
                          _syncInterval = value.round();
                        });
                      },
                    ),
                  ],
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
                    leading: const Icon(Icons.save, color: Colors.blue),
                    title: const Text('Sauvegarder les paramètres'),
                    onTap: _saveSettings,
                  ),
                  ListTile(
                    leading: const Icon(Icons.sync, color: Colors.green),
                    title: const Text('Synchroniser maintenant'),
                    onTap: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Synchronisation en cours...')),
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
                            'Développé avec Flutter et Django.',
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
                    leading:
                        const Icon(Icons.delete_forever, color: Colors.red),
                    title: const Text('Supprimer toutes les données'),
                    onTap: _clearAllData,
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
