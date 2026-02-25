import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/temperature_repository.dart';
import '../../../../data/models/temperature.dart';
import '../../../../data/repositories/appareil_repository.dart';
import '../../../../data/models/appareil.dart';
import '../../../../data/services/storage_service.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/utils/navigation_helpers.dart';
import 'appareils_management_page.dart';

/// Temperatures list page
class TemperaturesListPage extends StatefulWidget {
  const TemperaturesListPage({super.key});

  @override
  State<TemperaturesListPage> createState() => _TemperaturesListPageState();
}

class _TemperaturesListPageState extends State<TemperaturesListPage> {
  final _temperatureRepo = TemperatureRepository();
  final _appareilRepo = AppareilRepository();

  List<Temperature> _temperatures = [];
  List<Appareil> _appareils = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedAppareilId;
  DateTime? _startDate;
  DateTime? _endDate;

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
      final results = await Future.wait([
        _selectedAppareilId != null
            ? _temperatureRepo.getByAppareil(_selectedAppareilId!)
            : _temperatureRepo.getAll(startDate: _startDate, endDate: _endDate),
        _appareilRepo.getAll(),
      ]);

      if (mounted) {
        setState(() {
          _temperatures = results[0] as List<Temperature>;
          _appareils = results[1] as List<Appareil>;
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

  @override
  Widget build(BuildContext context) {
    final isAdminRoute = GoRouterState.of(
      context,
    ).matchedLocation.startsWith('/admin');
    final routePrefix = isAdminRoute ? '/admin' : '/app';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Températures'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavigationHelpers.goHaccpHub(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('$routePrefix/temperatures/new'),
            tooltip: 'Nouveau relevé',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/appareils'),
            tooltip: 'Gérer les appareils',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Filter by device
                if (_appareils.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedAppareilId,
                    decoration: const InputDecoration(
                      labelText: 'Filtrer par appareil',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.filter_list),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Tous les appareils'),
                      ),
                      ..._appareils.map(
                        (appareil) => DropdownMenuItem(
                          value: appareil.id,
                          child: Text(appareil.nom),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedAppareilId = value;
                      });
                      _loadData();
                    },
                  ),
                if (_appareils.isNotEmpty) const SizedBox(height: 12),
                // Date filters
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _startDate = date;
                            });
                            _loadData();
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date début',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _startDate != null
                                ? DateFormat('dd/MM/yyyy').format(_startDate!)
                                : 'Toutes',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? DateTime.now(),
                            firstDate: _startDate ?? DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _endDate = date;
                            });
                            _loadData();
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date fin',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _endDate != null
                                ? DateFormat('dd/MM/yyyy').format(_endDate!)
                                : 'Toutes',
                          ),
                        ),
                      ),
                    ),
                    if (_startDate != null || _endDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                          });
                          _loadData();
                        },
                        tooltip: 'Réinitialiser les dates',
                      ),
                  ],
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppTheme.statusCritical,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: TextStyle(color: AppTheme.statusCritical),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  )
                : _temperatures.isEmpty
                ? const EmptyState(
                    title: 'Aucune température',
                    message: 'Ajoutez votre premier relevé de température',
                    icon: Icons.thermostat,
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _temperatures.length,
                      itemBuilder: (context, index) {
                        final temp = _temperatures[index];
                        final appareil = _appareils.firstWhere(
                          (a) => a.id == temp.appareilId,
                          orElse: () => Appareil(
                            id: temp.appareilId,
                            nom: 'Appareil inconnu',
                            createdAt: DateTime.now(),
                          ),
                        );

                        final tempColor = _getTemperatureColor(
                          temp.temperature,
                          appareil.tempMin,
                          appareil.tempMax,
                        );
                        final isAlert =
                            (appareil.tempMin != null &&
                                temp.temperature < appareil.tempMin!) ||
                            (appareil.tempMax != null &&
                                temp.temperature > appareil.tempMax!);

                        return SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          appareil.nom,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              DateFormat(
                                                'dd/MM/yyyy à HH:mm',
                                              ).format(temp.createdAt),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Colors.grey[600],
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Temperature badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tempColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: tempColor,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.thermostat,
                                          size: 20,
                                          color: tempColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${temp.temperature}°C',
                                          style: TextStyle(
                                            color: tempColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Alert badge
                                  if (isAlert) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.statusCritical
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppTheme.statusCritical,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            size: 14,
                                            color: AppTheme.statusCritical,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'ALERTE',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.statusCritical,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (temp.remarque != null &&
                                  temp.remarque!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.note,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          temp.remarque!,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (temp.photoUrl != null &&
                                  temp.photoUrl!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Builder(
                                  builder: (context) {
                                    final photoUrl = temp.photoUrl!;
                                    final storageService = StorageService();

                                    // Check if it's a valid Supabase Storage URL
                                    final isValidUrl = storageService
                                        .isValidStorageUrl(photoUrl);
                                    final isLocalPath = storageService
                                        .isLocalPath(photoUrl);

                                    if (isLocalPath) {
                                      debugPrint(
                                        '[TemperaturesList] ⚠️ Photo has local path (not uploaded to Storage): $photoUrl',
                                      );
                                      debugPrint(
                                        '[TemperaturesList] This photo needs to be re-uploaded to Supabase Storage.',
                                      );
                                    } else if (isValidUrl) {
                                      debugPrint(
                                        '[TemperaturesList] ✅ Valid Supabase Storage URL: $photoUrl',
                                      );
                                    } else {
                                      debugPrint(
                                        '[TemperaturesList] ⚠️ Unknown photo URL format: $photoUrl',
                                      );
                                    }

                                    return InkWell(
                                      onTap: isValidUrl
                                          ? () {
                                              debugPrint(
                                                '[TemperaturesList] Opening photo: $photoUrl',
                                              );
                                              _showPhotoDialog(
                                                context,
                                                photoUrl,
                                              );
                                            }
                                          : null,
                                      child: Container(
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: isValidUrl
                                              ? Image.network(
                                                  photoUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    debugPrint(
                                                      '[TemperaturesList] ❌ Error loading photo: $error',
                                                    );
                                                    debugPrint(
                                                      '[TemperaturesList] Photo URL: $photoUrl',
                                                    );
                                                    return const Center(
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.broken_image,
                                                            size: 40,
                                                          ),
                                                          SizedBox(height: 4),
                                                          Text(
                                                            'Erreur de chargement',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                  loadingBuilder:
                                                      (
                                                        context,
                                                        child,
                                                        loadingProgress,
                                                      ) {
                                                        if (loadingProgress ==
                                                            null)
                                                          return child;
                                                        return const Center(
                                                          child:
                                                              CircularProgressIndicator(),
                                                        );
                                                      },
                                                )
                                              : Center(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        isLocalPath
                                                            ? Icons.upload_file
                                                            : Icons.warning,
                                                        size: 40,
                                                        color: Colors.orange,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        isLocalPath
                                                            ? 'Photo non uploadée'
                                                            : 'URL invalide',
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                      if (isLocalPath) ...[
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        const Text(
                                                          'Re-créer pour uploader',
                                                          style: TextStyle(
                                                            fontSize: 8,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                              if (temp.employeeFirstName != null &&
                                  temp.employeeLastName != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Effectué par: ${temp.employeeFirstName} ${temp.employeeLastName}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                              // Action buttons
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    color: AppTheme.primaryBlue,
                                    onPressed: () =>
                                        _editTemperature(context, temp),
                                    tooltip: 'Modifier',
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                    ),
                                    color: AppTheme.statusCritical,
                                    onPressed: () =>
                                        _deleteTemperature(context, temp),
                                    tooltip: 'Supprimer',
                                  ),
                                ],
                              ),
                            ],
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

  Future<void> _deleteTemperature(
    BuildContext context,
    Temperature temp,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer cette température (${temp.temperature}°C) ?',
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
      try {
        await _temperatureRepo.delete(temp.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Température supprimée')),
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

  void _editTemperature(BuildContext context, Temperature temp) {
    final isAdminRoute = GoRouterState.of(
      context,
    ).matchedLocation.startsWith('/admin');
    final routePrefix = isAdminRoute ? '/admin' : '/app';
    context.push('$routePrefix/temperatures/${temp.id}');
  }

  Color _getTemperatureColor(
    double temperature,
    double? tempMin,
    double? tempMax,
  ) {
    if (tempMin != null && temperature < tempMin) {
      return AppTheme.statusCritical;
    }
    if (tempMax != null && temperature > tempMax) {
      return AppTheme.statusCritical;
    }
    return AppTheme.statusOk;
  }

  void _showPhotoDialog(BuildContext context, String photoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      color: Colors.black87,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 64,
                            color: Colors.white,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Impossible de charger l\'image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      padding: const EdgeInsets.all(32),
                      color: Colors.black87,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
