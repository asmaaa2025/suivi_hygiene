import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../repositories/oil_change_repository.dart';
import '../../../../services/network_service.dart';
import '../../../../services/cache_service.dart';
import '../../../../exceptions/app_exceptions.dart';

class SuiviHuilePage extends StatefulWidget {
  const SuiviHuilePage({super.key});

  @override
  State<SuiviHuilePage> createState() => _SuiviHuilePageState();
}

class _SuiviHuilePageState extends State<SuiviHuilePage> {
  final _formKey = GlobalKey<FormState>();
  final _oilChangeRepo = OilChangeRepository();
  final _networkService = NetworkService();
  final _machineController = TextEditingController();
  final _typeHuileController = TextEditingController();
  final _quantiteController = TextEditingController();
  final _remarqueController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _changements = [];
  List<Map<String, dynamic>> _fryers = [];
  bool _isOnline = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkNetwork();
    _loadFryers();
    _loadChangements();
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

  Future<void> _loadFryers() async {
    try {
      final fryers = await _oilChangeRepo.getFryers();
      if (mounted) {
        setState(() {
          _fryers = fryers;
        });
      }
    } catch (e) {
      debugPrint('❌ [Suivi Huile] Erreur chargement friteuses: $e');
    }
  }

  @override
  void dispose() {
    _machineController.dispose();
    _typeHuileController.dispose();
    _quantiteController.dispose();
    _remarqueController.dispose();
    super.dispose();
  }

  Future<void> _loadChangements() async {
    setState(() => _isLoading = true);
    try {
      // Try cache first
      final cached = CacheService().get('oil_changes_all');
      if (cached != null) {
        setState(() {
          _changements = List<Map<String, dynamic>>.from(cached);
        });
      }

      // Load from Supabase
      final changements = await _oilChangeRepo.getAll();
      if (mounted) {
        setState(() {
          _changements = changements.map((c) {
            final dateStr = c['date'] as String?;
            final friteuseId = c['friteuse_id'] as String?;
            final fryer = _fryers.firstWhere(
              (f) => f['id'] == friteuseId,
              orElse: () => {'nom': 'Machine inconnue'},
            );
            return {
              ...c,
              'date':
                  dateStr != null ? DateTime.parse(dateStr) : DateTime.now(),
              'machine': fryer['nom'] ?? 'Machine inconnue',
            };
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Erreur: ${e is AppException ? e.message : e.toString()}'),
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveChangement() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network required')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final machineNom = _machineController.text.trim();
      final quantiteStr = _quantiteController.text.trim();
      final quantite =
          double.tryParse(quantiteStr.replaceAll(RegExp(r'[^0-9.]'), '')) ??
              0.0;

      // Find or create friteuse
      var friteuse = _fryers.firstWhere(
        (f) => (f['nom'] as String?)?.toLowerCase() == machineNom.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );

      String friteuseId;
      if (friteuse.isEmpty) {
        // Create new friteuse using base repository
        final newFriteuse = await _oilChangeRepo.client
            .from('friteuses')
            .insert({'nom': machineNom})
            .select()
            .single();
        friteuseId = newFriteuse['id'] as String;
        await _loadFryers();
      } else {
        friteuseId = friteuse['id'] as String;
      }

      // Save oil change
      await _oilChangeRepo.createOilChange(
        friteuseId: friteuseId,
        quantite: quantite,
        remarque: _remarqueController.text.trim().isEmpty
            ? null
            : _remarqueController.text.trim(),
      );

      // Reload list
      await _loadChangements();

      // Reset form
      _machineController.clear();
      _typeHuileController.clear();
      _quantiteController.clear();
      _remarqueController.clear();
      setState(() {
        _selectedDate = DateTime.now();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changement d\'huile enregistré')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Erreur: ${e is AppException ? e.message : e.toString()}'),
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
        title: const Text('Suivi d\'Huile'),
        backgroundColor: Colors.amber,
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
                  // Formulaire
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nouveau changement d\'huile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _machineController,
                              decoration: const InputDecoration(
                                labelText: 'Machine',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.build),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez entrer le nom de la machine';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _typeHuileController,
                              decoration: const InputDecoration(
                                labelText: 'Type d\'huile',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.opacity),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez entrer le type d\'huile';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _quantiteController,
                              decoration: const InputDecoration(
                                labelText: 'Quantité',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.straighten),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez entrer la quantité';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _remarqueController,
                              decoration: const InputDecoration(
                                labelText: 'Remarque (optionnel)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.note),
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: () => _selectDate(context),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  DateFormat('dd/MM/yyyy')
                                      .format(_selectedDate),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _saveChangement,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Enregistrer'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Liste des changements
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Historique des changements',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: constraints.maxHeight * 0.4,
                            ),
                            child: _changements.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Center(
                                      child: Text(
                                        'Aucun changement enregistré',
                                        style: TextStyle(
                                            color: Colors.grey.shade600),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    itemCount: _changements.length,
                                    itemBuilder: (context, index) {
                                      final changement = _changements[index];
                                      final date =
                                          changement['date'] is DateTime
                                              ? changement['date'] as DateTime
                                              : DateTime.parse(
                                                  changement['date'] as String);
                                      final quantite = changement['quantite'];
                                      final remarque =
                                          changement['remarque'] as String?;

                                      return Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          leading: const Icon(Icons.opacity,
                                              color: Colors.amber),
                                          title: Text(
                                            changement['machine'] ??
                                                'Machine inconnue',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (quantite != null)
                                                Text('Quantité: $quantite L'),
                                              Text(
                                                DateFormat('dd/MM/yyyy')
                                                    .format(date),
                                                style: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                              if (remarque?.isNotEmpty == true)
                                                Text(
                                                  remarque!,
                                                  style: const TextStyle(
                                                      fontStyle:
                                                          FontStyle.italic),
                                                ),
                                            ],
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () async {
                                              // TODO: Implement delete from DB
                                              await _loadChangements();
                                            },
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
