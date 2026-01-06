import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/personnel.dart';
import '../../../data/repositories/personnel_repository.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import 'personnel_form_page.dart';

/// Personnel registry page - CRUD for HR (Admin only)
class PersonnelRegistryPage extends StatefulWidget {
  const PersonnelRegistryPage({super.key});

  @override
  State<PersonnelRegistryPage> createState() => _PersonnelRegistryPageState();
}

class _PersonnelRegistryPageState extends State<PersonnelRegistryPage> {
  final PersonnelRepository _personnelRepo = PersonnelRepository();
  List<Personnel> _personnel = [];
  bool _isLoading = true;
  String? _error;
  bool _showActiveOnly = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final personnel = await _personnelRepo.getAll(
        activeOnly: _showActiveOnly,
        searchQuery: _searchController.text.isEmpty ? null : _searchController.text,
      );
      if (mounted) {
        setState(() {
          _personnel = personnel;
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

  Future<void> _deletePersonnel(Personnel personnel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Êtes-vous sûr de vouloir supprimer ${personnel.fullName} ?'),
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
      try {
        await _personnelRepo.softDelete(personnel.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Personnel supprimé')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registre du Personnel'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await context.push('/admin/rh/new');
              if (result == true) {
                _loadData();
              }
            },
            tooltip: 'Nouveau personnel',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Filter toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Afficher uniquement les actifs',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Switch(
                  value: _showActiveOnly,
                  onChanged: (value) {
                    setState(() {
                      _showActiveOnly = value;
                    });
                    _loadData();
                  },
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _loadData)
                    : _personnel.isEmpty
                        ? const EmptyState(
                            title: 'Aucun personnel',
                            message: 'Ajoutez votre premier membre du personnel',
                            icon: Icons.person_add,
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _personnel.length,
                              itemBuilder: (context, index) {
                                final p = _personnel[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: p.isActive
                                          ? AppTheme.primaryBlue
                                          : Colors.grey,
                                      child: Text(
                                        p.firstName[0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    title: Text(
                                      p.fullName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        decoration: p.isActive
                                            ? null
                                            : TextDecoration.lineThrough,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Contrat: ${p.contractType.displayName}'),
                                        Text(
                                          'Entrée: ${DateFormat('dd/MM/yyyy').format(p.startDate)}',
                                        ),
                                        if (p.endDate != null)
                                          Text(
                                            'Sortie: ${DateFormat('dd/MM/yyyy').format(p.endDate!)}',
                                            style: const TextStyle(color: Colors.red),
                                          ),
                                        if (p.isForeignWorker)
                                          Text(
                                            'Travailleur étranger',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: PopupMenuButton(
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          child: const Text('Modifier'),
                                          onTap: () async {
                                            await Future.delayed(
                                              const Duration(milliseconds: 100),
                                            );
                                            final result = await context.push(
                                              '/admin/rh/${p.id}',
                                            );
                                            if (result == true) {
                                              _loadData();
                                            }
                                          },
                                        ),
                                        PopupMenuItem(
                                          child: const Text(
                                            'Supprimer',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                          onTap: () {
                                            Future.delayed(
                                              const Duration(milliseconds: 100),
                                            ).then((_) => _deletePersonnel(p));
                                          },
                                        ),
                                      ],
                                    ),
                                    onTap: () async {
                                      final result = await context.push(
                                        '/admin/rh/${p.id}',
                                      );
                                      if (result == true) {
                                        _loadData();
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

