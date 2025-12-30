import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/temperature_repository.dart';
import '../../../../data/models/temperature.dart';
import '../../../../data/repositories/appareil_repository.dart';
import '../../../../data/models/appareil.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
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
            : _temperatureRepo.getAll(
                startDate: _startDate,
                endDate: _endDate,
              ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Températures'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/temperatures/new'),
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
                      ..._appareils.map((appareil) => DropdownMenuItem(
                            value: appareil.id,
                            child: Text(appareil.nom),
                          )),
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
                            Icon(Icons.error_outline,
                                size: 64, color: AppTheme.statusCritical),
                            const SizedBox(height: 16),
                            Text(_error!,
                                style: TextStyle(color: AppTheme.statusCritical)),
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
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${temp.temperature}°C',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headlineSmall
                                                      ?.copyWith(
                                                        color: _getTemperatureColor(
                                                          temp.temperature,
                                                          appareil.tempMin,
                                                          appareil.tempMax,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            DateFormat('dd/MM/yyyy HH:mm')
                                                .format(temp.createdAt),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                      if (temp.remarque != null &&
                                          temp.remarque!.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          temp.remarque!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                      ],
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
}
