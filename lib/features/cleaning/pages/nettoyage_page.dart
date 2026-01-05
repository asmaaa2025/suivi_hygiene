import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../services/network_service.dart';
import '../../../../data/repositories/tache_nettoyage_repository.dart';

class NettoyagePage extends StatefulWidget {
  const NettoyagePage({super.key});

  @override
  State<NettoyagePage> createState() => _NettoyagePageState();
}

class _NettoyagePageState extends State<NettoyagePage> {
  final _formKey = GlobalKey<FormState>();
  final _cleaningRepo = TacheNettoyageRepository();
  final _networkService = NetworkService();
  final _remarqueController = TextEditingController();

  String _selectedAction = 'Nettoyage plan de travail';
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _nettoyages = [];
  bool _isOnline = true;
  bool _isLoading = false;

  final List<String> _actionsNettoyage = [
    'Nettoyage plan de travail',
    'Nettoyage frigos',
    'Désinfection sols',
    'Vider poubelles',
    'Contrôle visuel hygiène',
    'Nettoyage équipements',
    'Désinfection surfaces',
    'Nettoyage vitrines',
  ];

  @override
  void initState() {
    super.initState();
    _checkNetwork();
    _loadNettoyages();
    _networkService.connectivityStream.listen((_) => _checkNetwork());
  }

  Future<void> _checkNetwork() async {
    final isOnline = await _networkService.hasConnection();
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
      });
    }
  }

  @override
  void dispose() {
    _remarqueController.dispose();
    super.dispose();
  }

  Future<void> _loadNettoyages() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      debugPrint('[NettoyagePage] Loading nettoyages from Supabase');
      // Load from Supabase directly (no cache)
      final taches = await _cleaningRepo.getAll();
      final nettoyages = taches
          .map((t) => <String, dynamic>{
                'id': t.id,
                'nom': t.nom,
                'date': t.createdAt.toIso8601String(),
                'is_active': t.isActive,
              })
          .toList();

      debugPrint('[NettoyagePage] ✅ Loaded ${nettoyages.length} nettoyages');

      if (mounted) {
        setState(() {
          // Convert to Map format for compatibility with existing UI
          _nettoyages = nettoyages
              .map((n) => <String, dynamic>{
                    'id': n['id'],
                    'action': n['nom'] ?? 'Nettoyage',
                    'statut': (n['is_active'] == true) ? 'Actif' : 'Inactif',
                    'remarque': '',
                    'date': n['date'],
                  })
              .toList();
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[NettoyagePage] ❌ Error loading nettoyages: $e');
      debugPrint('[NettoyagePage] StackTrace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _ajouterNettoyage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      debugPrint(
          '[NettoyagePage] Creating nettoyage for action: $_selectedAction');

      // Note: This page uses old format. For now, we'll create a simple task-based nettoyage
      // In production, you'd want to map _selectedAction to a tache_id
      // For now, we'll skip creation and show a message
      debugPrint(
          '[NettoyagePage] ⚠️ Old format detected. Use CleaningPage instead.');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Cette page utilise un format obsolète. Utilisez la page Nettoyage principale.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[NettoyagePage] ❌ Error creating nettoyage: $e');
      debugPrint('[NettoyagePage] StackTrace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'Suivi Nettoyage',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 16.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
              ),
              child: Column(
                children: [
                  // Formulaire d'ajout
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nouveau Nettoyage',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Sélection de l'action
                            DropdownButtonFormField<String>(
                              value: _selectedAction,
                              decoration: const InputDecoration(
                                labelText: 'Action de nettoyage',
                                border: OutlineInputBorder(),
                              ),
                              items: _actionsNettoyage.map((String action) {
                                return DropdownMenuItem<String>(
                                  value: action,
                                  child: Text(action),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedAction = newValue!;
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // Date
                            InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  setState(() {
                                    _selectedDate = date;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date',
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(DateFormat('dd/MM/yyyy')
                                    .format(_selectedDate)),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Remarque
                            TextFormField(
                              controller: _remarqueController,
                              decoration: const InputDecoration(
                                labelText: 'Remarque (optionnel)',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),

                            // Bouton d'ajout
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _ajouterNettoyage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: Text(
                                  'Enregistrer le nettoyage',
                                  style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Liste des nettoyages
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Historique des nettoyages',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Use ConstrainedBox to limit height for list
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: constraints.maxHeight * 0.5,
                            ),
                            child: _nettoyages.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Center(
                                      child: Text(
                                        'Aucun nettoyage enregistré',
                                        style: GoogleFonts.montserrat(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    itemCount: _nettoyages.length,
                                    itemBuilder: (context, index) {
                                      final nettoyage = _nettoyages[index];
                                      return Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.cleaning_services,
                                            color: Colors.blue.shade600,
                                          ),
                                          title: Text(
                                            nettoyage['action'] ?? 'N/A',
                                            style: GoogleFonts.montserrat(
                                                fontWeight: FontWeight.w600),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                DateFormat('dd/MM/yyyy HH:mm')
                                                    .format(
                                                  DateTime.parse(nettoyage[
                                                          'date'] ??
                                                      DateTime.now()
                                                          .toIso8601String()),
                                                ),
                                              ),
                                              if (nettoyage['remarque']
                                                      ?.isNotEmpty ==
                                                  true)
                                                Text(nettoyage['remarque']),
                                            ],
                                          ),
                                          trailing: Chip(
                                            label: Text(
                                              nettoyage['statut'] ?? 'Terminé',
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
                                            backgroundColor:
                                                Colors.green.shade600,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
