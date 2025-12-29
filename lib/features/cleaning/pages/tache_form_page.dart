import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/tache_nettoyage_repository.dart';

/// Form page for creating/editing a cleaning task
class TacheFormPage extends StatefulWidget {
  final String? tacheId;

  const TacheFormPage({super.key, this.tacheId});

  @override
  State<TacheFormPage> createState() => _TacheFormPageState();
}

class _TacheFormPageState extends State<TacheFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _timeController = TextEditingController();
  final _tacheRepo = TacheNettoyageRepository();

  String _recurrenceType = 'daily';
  int _interval = 1;
  List<int> _selectedWeekdays = [];
  int? _dayOfMonth;
  TimeOfDay _timeOfDay = TimeOfDay.now();
  bool _isActive = true;
  bool _isLoading = false;
  bool _isEditMode = false;

  final List<String> _weekdayNames = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche'
  ];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.tacheId != null;
    _timeController.text = DateFormat('HH:mm').format(
      DateTime(2000, 1, 1, _timeOfDay.hour, _timeOfDay.minute),
    );
    if (_isEditMode) {
      _loadTache();
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _loadTache() async {
    if (widget.tacheId == null) return;

    setState(() => _isLoading = true);

    try {
      final tache = await _tacheRepo.getById(widget.tacheId!);
      setState(() {
        _nomController.text = tache.nom;
        _recurrenceType = tache.recurrenceType;
        _interval = tache.interval;
        _selectedWeekdays = tache.weekdays ?? [];
        _dayOfMonth = tache.dayOfMonth;
        final timeParts = tache.timeOfDay.split(':');
        _timeOfDay = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
        _timeController.text = tache.timeOfDay;
        _isActive = tache.isActive;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
        context.pop();
      }
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeOfDay,
    );
    if (picked != null) {
      setState(() {
        _timeOfDay = picked;
        _timeController.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_recurrenceType == 'weekly' && _selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sélectionnez au moins un jour de la semaine')),
      );
      return;
    }

    if (_recurrenceType == 'monthly' && _dayOfMonth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un jour du mois')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isEditMode && widget.tacheId != null) {
        await _tacheRepo.update(
          id: widget.tacheId!,
          nom: _nomController.text.trim(),
          recurrenceType: _recurrenceType,
          interval: _interval,
          weekdays: _recurrenceType == 'weekly' ? _selectedWeekdays : null,
          dayOfMonth: _recurrenceType == 'monthly' ? _dayOfMonth : null,
          timeOfDay: _timeController.text,
          isActive: _isActive,
        );
      } else {
        await _tacheRepo.create(
          nom: _nomController.text.trim(),
          recurrenceType: _recurrenceType,
          interval: _interval,
          weekdays: _recurrenceType == 'weekly' ? _selectedWeekdays : null,
          dayOfMonth: _recurrenceType == 'monthly' ? _dayOfMonth : null,
          timeOfDay: _timeController.text,
          isActive: _isActive,
        );
      }

      if (mounted) {
        context.pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'Tâche modifiée' : 'Tâche créée'),
            backgroundColor: AppTheme.statusOk,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
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
      appBar: AppBar(
        title: Text(_isEditMode ? 'Modifier tâche' : 'Nouvelle tâche'),
      ),
      body: _isLoading && _isEditMode
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nomController,
                    decoration: const InputDecoration(
                      labelText: 'Nom de la tâche *',
                      prefixIcon: Icon(Icons.cleaning_services),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Veuillez entrer un nom';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _recurrenceType,
                    decoration: const InputDecoration(
                      labelText: 'Type de récurrence *',
                      prefixIcon: Icon(Icons.repeat),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'daily', child: Text('Quotidien')),
                      DropdownMenuItem(
                          value: 'weekly', child: Text('Hebdomadaire')),
                      DropdownMenuItem(
                          value: 'monthly', child: Text('Mensuel')),
                    ],
                    onChanged: (value) =>
                        setState(() => _recurrenceType = value!),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _interval.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Intervalle *',
                            prefixIcon: Icon(Icons.numbers),
                            helperText: 'Ex: 1 = chaque jour/semaine/mois',
                          ),
                          onChanged: (value) {
                            _interval = int.tryParse(value) ?? 1;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _recurrenceType == 'daily'
                              ? 'jour(s)'
                              : _recurrenceType == 'weekly'
                                  ? 'semaine(s)'
                                  : 'mois',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                  if (_recurrenceType == 'weekly') ...[
                    const SizedBox(height: 16),
                    Text(
                      'Jours de la semaine *',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: List.generate(7, (index) {
                        final dayIndex = index + 1;
                        final isSelected = _selectedWeekdays.contains(dayIndex);
                        return FilterChip(
                          label: Text(_weekdayNames[index]),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedWeekdays.add(dayIndex);
                              } else {
                                _selectedWeekdays.remove(dayIndex);
                              }
                            });
                          },
                        );
                      }),
                    ),
                  ],
                  if (_recurrenceType == 'monthly') ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _dayOfMonth,
                      decoration: const InputDecoration(
                        labelText: 'Jour du mois *',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      items: List.generate(31, (index) {
                        final day = index + 1;
                        return DropdownMenuItem(
                          value: day,
                          child: Text('$day${day == 1 ? 'er' : ''}'),
                        );
                      }),
                      onChanged: (value) => setState(() => _dayOfMonth = value),
                    ),
                  ],
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Heure *',
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(_timeController.text),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Tâche active'),
                    subtitle: const Text(
                        'Les tâches inactives ne seront pas affichées dans la todo list'),
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditMode ? 'Modifier' : 'Créer'),
                  ),
                ],
              ),
            ),
    );
  }
}
