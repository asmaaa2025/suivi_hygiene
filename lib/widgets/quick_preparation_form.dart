import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/produit.dart';

class QuickPreparationForm extends StatefulWidget {
  final Produit produit;
  final Function(
    String lot,
    double poids,
    String? preparateur,
    DateTime dateFabrication,
    bool surgeler,
  )
  onValidate;

  const QuickPreparationForm({
    super.key,
    required this.produit,
    required this.onValidate,
  });

  @override
  State<QuickPreparationForm> createState() => _QuickPreparationFormState();
}

class _QuickPreparationFormState extends State<QuickPreparationForm> {
  final _lotController = TextEditingController();
  final _poidsController = TextEditingController();
  final _prepController = TextEditingController();
  DateTime _dateFab = DateTime.now();
  bool _isSurgel = false;

  @override
  void dispose() {
    _lotController.dispose();
    _poidsController.dispose();
    _prepController.dispose();
    super.dispose();
  }

  Future<void> _printEtiquette() async {
    final pdf = pw.Document();

    // Calculer la DLC avec option de surgélation
    final dlc = widget.produit.computeDlc(_dateFab, surgeler: _isSurgel);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        build: (pw.Context context) => pw.Container(
          padding: const pw.EdgeInsets.all(15),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // En-tête
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Text(
                  'ÉTIQUETTE PRODUIT',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 15),

              // Informations du produit
              _buildInfoRow('Produit:', widget.produit.nom),
              _buildInfoRow(
                'Date fabrication:',
                DateFormat('dd/MM/yyyy').format(_dateFab),
              ),
              _buildInfoRow('DLC:', DateFormat('dd/MM/yyyy').format(dlc)),
              _buildInfoRow('Lot:', _lotController.text),
              _buildInfoRow('Poids:', '${_poidsController.text} kg'),
              if (_prepController.text.isNotEmpty)
                _buildInfoRow('Préparateur:', _prepController.text),
              if (_isSurgel) _buildInfoRow('Conservation:', 'SURGELÉ'),

              pw.SizedBox(height: 20),

              // Code-barres
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                child: pw.Text(
                  'Code: ${_lotController.text}-${DateFormat('ddMMyyyy').format(dlc)}',
                  style: const pw.TextStyle(fontSize: 12),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        24,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Préparation - ${widget.produit.nom}",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _lotController,
              decoration: InputDecoration(
                labelText: "Numéro de lot *",
                prefixIcon: Icon(Icons.qr_code),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _poidsController,
              decoration: InputDecoration(
                labelText: "Poids (kg) *",
                prefixIcon: Icon(Icons.scale),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _prepController,
              decoration: InputDecoration(
                labelText: "Préparateur (optionnel)",
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            ListTile(
              title: Text(
                "Date de fabrication: ${_dateFab.day.toString().padLeft(2, '0')}/${_dateFab.month.toString().padLeft(2, '0')}/${_dateFab.year}",
              ),
              leading: Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateFab,
                  firstDate: DateTime.now().subtract(Duration(days: 30)),
                  lastDate: DateTime.now().add(Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() {
                    _dateFab = picked;
                  });
                }
              },
            ),
            if (widget.produit.surgelagable)
              SwitchListTile(
                title: Text("Produit surgelé ?"),
                subtitle: Text(
                  _isSurgel
                      ? "DLC: +${widget.produit.dlcSurgelationJours ?? widget.produit.dlcJours} jours"
                      : "DLC: +${widget.produit.dlcJours} jours",
                ),
                value: _isSurgel,
                onChanged: (val) => setState(() => _isSurgel = val),
              ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.print),
                label: Text("Imprimer l'étiquette"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  if (_lotController.text.isEmpty ||
                      _poidsController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Veuillez remplir les champs obligatoires.",
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  final poids = double.tryParse(_poidsController.text);
                  if (poids == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Poids invalide."),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  // Appeler la fonction de validation
                  widget.onValidate(
                    _lotController.text,
                    poids,
                    _prepController.text.isNotEmpty
                        ? _prepController.text
                        : null,
                    _dateFab,
                    _isSurgel,
                  );

                  // Imprimer l'étiquette
                  await _printEtiquette();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
