/// Plan de rappel - Gestion des crises sanitaires
/// PMS - Règlement 178/2002

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/navigation_helpers.dart';
import '../../../data/models/rappel.dart';
import '../../../data/repositories/rappel_repository.dart';

class PlanRappelPage extends StatefulWidget {
  const PlanRappelPage({super.key});

  @override
  State<PlanRappelPage> createState() => _PlanRappelPageState();
}

class _PlanRappelPageState extends State<PlanRappelPage> {
  final _repo = RappelRepository();
  List<Rappel> _rappels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.getAll();
      if (mounted) setState(() {
        _rappels = list;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavigationHelpers.goHaccpHub(context),
        ),
        title: const Text('Plan de rappel'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showRappelForm(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rappels.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rappels.length,
                    itemBuilder: (context, i) {
                      final r = _rappels[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _statutColor(r.statut),
                            child: Icon(Icons.warning, color: Colors.white, size: 20),
                          ),
                          title: Text(r.produitNom, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (r.lot != null) Text('Lot: ${r.lot}'),
                              Text('${DateFormat('dd/MM/yyyy').format(r.dateDetection)} - ${r.statut.displayName}'),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                              const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                            ],
                            onSelected: (v) {
                              if (v == 'edit') _showRappelForm(rappel: r);
                              if (v == 'delete') _confirmDelete(r);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Color _statutColor(RappelStatut s) {
    switch (s) {
      case RappelStatut.ouvert: return Colors.red;
      case RappelStatut.enCours: return Colors.orange;
      case RappelStatut.clos: return Colors.green;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun rappel enregistré',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'En cas de crise sanitaire, déclarez un rappel de produit ici.\nRèglement 178/2002 - Traçabilité.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showRappelForm(),
              icon: const Icon(Icons.add),
              label: const Text('Déclarer un rappel'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRappelForm({Rappel? rappel}) {
    final isEdit = rappel != null;
    final nomCtrl = TextEditingController(text: rappel?.produitNom ?? '');
    final lotCtrl = TextEditingController(text: rappel?.lot ?? '');
    final fournisseurCtrl = TextEditingController(text: rappel?.fournisseur ?? '');
    final motifCtrl = TextEditingController(text: rappel?.motif ?? '');
    final actionsCtrl = TextEditingController(text: rappel?.actionsPrises ?? '');
    final ddppCtrl = TextEditingController(text: rappel?.contactDdpp ?? '');
    var date = rappel?.dateDetection ?? DateTime.now();
    var statut = rappel?.statut ?? RappelStatut.ouvert;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(isEdit ? 'Modifier le rappel' : 'Déclarer un rappel', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(controller: nomCtrl, decoration: const InputDecoration(labelText: 'Produit *'), textCapitalization: TextCapitalization.words),
              TextField(controller: lotCtrl, decoration: const InputDecoration(labelText: 'Lot')),
              TextField(controller: fournisseurCtrl, decoration: const InputDecoration(labelText: 'Fournisseur')),
              TextField(controller: motifCtrl, decoration: const InputDecoration(labelText: 'Motif du rappel *'), maxLines: 2),
              ListTile(
                title: Text('Date détection: ${DateFormat('dd/MM/yyyy').format(date)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (d != null) setModalState(() => date = d);
                },
              ),
              DropdownButtonFormField<RappelStatut>(
                value: statut,
                decoration: const InputDecoration(labelText: 'Statut'),
                items: RappelStatut.values.map((s) => DropdownMenuItem(value: s, child: Text(s.displayName))).toList(),
                onChanged: (v) => setModalState(() => statut = v ?? RappelStatut.ouvert),
              ),
              TextField(controller: actionsCtrl, decoration: const InputDecoration(labelText: 'Actions prises'), maxLines: 2),
              TextField(controller: ddppCtrl, decoration: const InputDecoration(labelText: 'Contact DDPP')),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler'))),
                  const SizedBox(width: 16),
                  Expanded(child: FilledButton(onPressed: () async {
                    if (nomCtrl.text.trim().isEmpty || motifCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produit et motif requis')));
                      return;
                    }
                    try {
                      final r = Rappel(
                        id: rappel?.id ?? '',
                        produitNom: nomCtrl.text.trim(),
                        lot: lotCtrl.text.trim().isEmpty ? null : lotCtrl.text.trim(),
                        fournisseur: fournisseurCtrl.text.trim().isEmpty ? null : fournisseurCtrl.text.trim(),
                        motif: motifCtrl.text.trim(),
                        dateDetection: date,
                        statut: statut,
                        actionsPrises: actionsCtrl.text.trim().isEmpty ? null : actionsCtrl.text.trim(),
                        contactDdpp: ddppCtrl.text.trim().isEmpty ? null : ddppCtrl.text.trim(),
                        organizationId: rappel?.organizationId,
                        createdAt: rappel?.createdAt ?? DateTime.now(),
                        createdBy: rappel?.createdBy,
                      );
                      if (isEdit) {
                        await _repo.update(Rappel(
                          id: rappel!.id,
                          produitNom: nomCtrl.text.trim(),
                          lot: lotCtrl.text.trim().isEmpty ? null : lotCtrl.text.trim(),
                          fournisseur: fournisseurCtrl.text.trim().isEmpty ? null : fournisseurCtrl.text.trim(),
                          motif: motifCtrl.text.trim(),
                          dateDetection: date,
                          statut: statut,
                          actionsPrises: actionsCtrl.text.trim().isEmpty ? null : actionsCtrl.text.trim(),
                          contactDdpp: ddppCtrl.text.trim().isEmpty ? null : ddppCtrl.text.trim(),
                          organizationId: rappel.organizationId,
                          createdAt: rappel.createdAt,
                          createdBy: rappel.createdBy,
                        ));
                      } else {
                        await _repo.create(r);
                      }
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        _load();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'Rappel modifié' : 'Rappel déclaré')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                      }
                    }
                  }, child: Text(isEdit ? 'Modifier' : 'Enregistrer'))),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  void _confirmDelete(Rappel r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le rappel ?'),
        content: Text('Rappel: ${r.produitNom}${r.lot != null ? " (Lot: ${r.lot})" : ""}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(onPressed: () async {
            await _repo.delete(r.id);
            if (mounted) {
              Navigator.pop(ctx);
              _load();
            }
          }, child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
