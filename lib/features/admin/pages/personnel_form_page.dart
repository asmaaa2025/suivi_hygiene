import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/personnel.dart';
import '../../../data/repositories/personnel_repository.dart';

/// Personnel form page for create/edit
class PersonnelFormPage extends StatefulWidget {
  final String? personnelId;

  const PersonnelFormPage({super.key, this.personnelId});

  @override
  State<PersonnelFormPage> createState() => _PersonnelFormPageState();
}

class _PersonnelFormPageState extends State<PersonnelFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _personnelRepo = PersonnelRepository();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _permitTypeController = TextEditingController();
  final _permitNumberController = TextEditingController();
  
  DateTime? _startDate;
  DateTime? _endDate;
  ContractType _contractType = ContractType.cdi;
  bool _isForeignWorker = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.personnelId != null) {
      _loadPersonnel();
    } else {
      _isLoading = false;
      _startDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _permitTypeController.dispose();
    _permitNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadPersonnel() async {
    try {
      final personnel = await _personnelRepo.getById(widget.personnelId!);
      if (personnel != null && mounted) {
        setState(() {
          _firstNameController.text = personnel.firstName;
          _lastNameController.text = personnel.lastName;
          _startDate = personnel.startDate;
          _endDate = personnel.endDate;
          _contractType = personnel.contractType;
          _isForeignWorker = personnel.isForeignWorker;
          _permitTypeController.text = personnel.foreignWorkPermitType ?? '';
          _permitNumberController.text = personnel.foreignWorkPermitNumber ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La date de début est requise')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.personnelId != null) {
        await _personnelRepo.update(
          id: widget.personnelId!,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          startDate: _startDate!,
          endDate: _endDate,
          contractType: _contractType,
          isForeignWorker: _isForeignWorker,
          foreignWorkPermitType:
              _isForeignWorker ? _permitTypeController.text.trim() : null,
          foreignWorkPermitNumber:
              _isForeignWorker ? _permitNumberController.text.trim() : null,
        );
      } else {
        await _personnelRepo.create(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          startDate: _startDate!,
          endDate: _endDate,
          contractType: _contractType,
          isForeignWorker: _isForeignWorker,
          foreignWorkPermitType:
              _isForeignWorker ? _permitTypeController.text.trim() : null,
          foreignWorkPermitNumber:
              _isForeignWorker ? _permitNumberController.text.trim() : null,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Personnel enregistré'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    bool isStartDate,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Personnel')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.personnelId != null ? 'Modifier' : 'Nouveau personnel'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'Prénom *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Le prénom est requis';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Nom *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Le nom est requis';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Start date
            InkWell(
              onTap: () => _selectDate(context, true),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date d\'entrée *',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _startDate != null
                      ? DateFormat('dd/MM/yyyy').format(_startDate!)
                      : 'Sélectionner',
                ),
              ),
            ),
            const SizedBox(height: 16),
            // End date
            InkWell(
              onTap: () => _selectDate(context, false),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date de sortie (optionnel)',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _endDate != null
                      ? DateFormat('dd/MM/yyyy').format(_endDate!)
                      : 'Non définie',
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Contract type
            DropdownButtonFormField<ContractType>(
              value: _contractType,
              decoration: const InputDecoration(
                labelText: 'Type de contrat *',
                border: OutlineInputBorder(),
              ),
              items: ContractType.values
                  .where((e) => !e.toString().endsWith('En'))
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _contractType = value);
                }
              },
            ),
            const SizedBox(height: 16),
            // Foreign worker toggle
            SwitchListTile(
              title: const Text('Travailleur étranger'),
              value: _isForeignWorker,
              onChanged: (value) {
                setState(() => _isForeignWorker = value);
              },
            ),
            if (_isForeignWorker) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _permitTypeController,
                decoration: const InputDecoration(
                  labelText: 'Type de permis *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (_isForeignWorker &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Le type de permis est requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _permitNumberController,
                decoration: const InputDecoration(
                  labelText: 'Numéro de permis *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (_isForeignWorker &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Le numéro de permis est requis';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

