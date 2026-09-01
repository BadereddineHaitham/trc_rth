import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfReportService {
  static final PdfReportService instance = PdfReportService._();
  PdfReportService._();

  String _clean(String text) {
    if (text.isEmpty) return text;
    return text
        .replaceAll('—', ' - ')
        .replaceAll('–', ' - ')
        .replaceAll('’', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"');
  }

  Future<Uint8List> _loadLogo() async {
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.jpeg');
      return data.buffer.asUint8List();
    } catch (_) {
      return Uint8List(0);
    }
  }

  /// Print or share vehicle full technical sheet + equipment + maintenance history PDF
  Future<void> printVehiclePdf({
    required Map<String, dynamic> vehicle,
    required List<Map<String, dynamic>> equipmentList,
    required List<Map<String, dynamic>> maintenanceRecords,
  }) async {
    final logoBytes = await _loadLogo();
    final pdf = pw.Document();

    final name = _clean((vehicle['name'] as String?) ?? 'Véhicule');
    final type = _clean((vehicle['type'] as String?) ?? (vehicle['vehicle_type'] as String?) ?? 'Spécialisé');
    final matricule = _clean((vehicle['matricule'] as String?) ?? (vehicle['id'] as String?) ?? '-');
    final affectation = _clean((vehicle['affectation'] as String?) ?? '-');
    final status = _clean((vehicle['status'] as String?) ?? 'operational');
    final insurance = _clean((vehicle['insurance_expiry'] as String?) ?? 'Non renseigné');
    final inspection = _clean((vehicle['inspection_expiry'] as String?) ?? 'Non renseigné');
    final dateFormatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoBytes.isNotEmpty)
                    pw.Image(pw.MemoryImage(logoBytes), width: 65, height: 65)
                  else
                    pw.Container(width: 65, height: 65),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'SONATRACH - TRC RTH',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.amber900,
                        ),
                      ),
                      pw.Text(
                        'Direction Régionale Transport Hydrocarbures',
                        style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Édité le: $dateFormatted',
                        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1.5, color: PdfColors.amber900),
              pw.SizedBox(height: 6),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Sanad Sonatrach TRC RTH - Document Officiel', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Page ${context.pageNumber} sur ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Document Title
            pw.Center(
              child: pw.Text(
                'FICHE TECHNIQUE & HISTORIQUE DE MAINTENANCE VÉHICULE',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),
            ),
            pw.SizedBox(height: 12),

            // Vehicle Details Box
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                color: PdfColors.grey100,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('INFORMATIONS GÉNÉRALES VÉHICULE', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildInfoItem('Nom:', name)),
                      pw.Expanded(child: _buildInfoItem('Matricule:', matricule)),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildInfoItem('Type:', type)),
                      pw.Expanded(child: _buildInfoItem('Affectation:', affectation)),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildInfoItem('Statut:', status.toUpperCase())),
                      pw.Expanded(child: _buildInfoItem('Assurance Expiration:', insurance)),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildInfoItem('Contrôle Technique:', inspection)),
                      pw.Expanded(child: pw.Container()),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Section 1: Équipements / Armement
            pw.Text(
              'ÉQUIPEMENTS & ARMEMENT (${equipmentList.length})',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
            ),
            pw.SizedBox(height: 5),
            if (equipmentList.isEmpty)
              pw.Text('Aucun équipement renseigné.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
            else
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.amber900),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3.5),
                  1: const pw.FlexColumnWidth(2.0),
                  2: const pw.FlexColumnWidth(4.5),
                },
                headers: ['Équipement', 'Quantité', 'Observation'],
                data: equipmentList.map((eq) {
                  final def = (eq['equipment_definitions'] as Map<String, dynamic>?) ?? {};
                  final eqName = _clean((def['name'] as String?) ??
                      (eq['designation'] as String?) ??
                      (eq['name'] as String?) ??
                      'Équipement');

                  final stdQty = (eq['standard_quantity'] as int?) ?? (eq['standard'] as int?) ?? 0;
                  final extQty = (eq['existing_quantity'] as int?) ?? (eq['existing'] as int?) ?? 0;
                  final qtyStr = (stdQty > 0 || extQty > 0)
                      ? '$extQty (Exist.) / $stdQty (Std.)'
                      : '${eq['quantity'] ?? 1}';

                  final obs = _clean((eq['observation'] as String?) ??
                      (eq['notes'] as String?) ??
                      (eq['remark'] as String?) ??
                      (extQty < stdQty && stdQty > 0 ? 'Manquant (${stdQty - extQty})' : 'R.A.S'));

                  return [eqName, qtyStr, obs];
                }).toList(),
              ),
            pw.SizedBox(height: 14),

            // Section 2: Historique de Maintenance
            pw.Text(
              'HISTORIQUE DE MAINTENANCE (${maintenanceRecords.length})',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
            ),
            pw.SizedBox(height: 5),
            if (maintenanceRecords.isEmpty)
              pw.Text('Aucune opération de maintenance enregistrée.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
            else
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: const pw.TextStyle(fontSize: 7.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2), // Date
                  1: const pw.FlexColumnWidth(1.1), // Type
                  2: const pw.FlexColumnWidth(3.0), // Description
                  3: const pw.FlexColumnWidth(1.5), // Responsable
                  4: const pw.FlexColumnWidth(1.5), // Prestataire
                  5: const pw.FlexColumnWidth(1.0), // Statut
                },
                headers: ['Date', 'Type', 'Description', 'Responsable', 'Prestataire', 'Statut'],
                data: maintenanceRecords.map((m) {
                  final date = _clean((m['maintenance_date'] as String?) ?? (m['date'] as String?) ?? '-');
                  final mType = _clean((m['maintenance_type'] as String?) ?? (m['type'] as String?) ?? '-');
                  final desc = _clean((m['description'] as String?) ?? '-');
                  final resp = _clean((m['responsible'] as String?) ?? '-');
                  final prov = _clean((m['provider'] as String?) ?? '-');
                  final stat = _clean((m['maintenance_status'] as String?) ?? (m['status'] as String?) ?? 'Terminé');
                  return [date, mType, desc, resp, prov, stat];
                }).toList(),
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Rapport_Vehicule_${name.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Print or share fixed equipment technical sheet + maintenance history PDF
  Future<void> printFixedEquipmentPdf({
    required Map<String, dynamic> equipment,
    required List<Map<String, dynamic>> maintenanceRecords,
  }) async {
    final logoBytes = await _loadLogo();
    final pdf = pw.Document();

    final name = _clean((equipment['name'] as String?) ?? 'Équipement Fixe');
    final category = _clean((equipment['category'] as String?) ?? 'Général');
    final location = _clean((equipment['location'] as String?) ?? '-');
    final status = _clean((equipment['status'] as String?) ?? 'operational');
    final isUSD = category.toUpperCase().contains('USD');
    final dateFormatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    Map<String, dynamic> usdDetails = {};
    final rawUsd = equipment['usd_details'];
    if (rawUsd is Map<String, dynamic>) usdDetails = rawUsd;
    if (rawUsd is Map) usdDetails = Map<String, dynamic>.from(rawUsd);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoBytes.isNotEmpty)
                    pw.Image(pw.MemoryImage(logoBytes), width: 65, height: 65)
                  else
                    pw.Container(width: 65, height: 65),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'SONATRACH - TRC RTH',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.amber900,
                        ),
                      ),
                      pw.Text(
                        'Direction Régionale Transport Hydrocarbures',
                        style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Édité le: $dateFormatted',
                        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1.5, color: PdfColors.amber900),
              pw.SizedBox(height: 6),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Sanad Sonatrach TRC RTH - Document Officiel', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Page ${context.pageNumber} sur ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Document Title
            pw.Center(
              child: pw.Text(
                'FICHE ÉQUIPEMENT FIXE & HISTORIQUE DE MAINTENANCE',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),
            ),
            pw.SizedBox(height: 12),

            // Equipment Info Box
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                color: PdfColors.grey100,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('INFORMATIONS ÉQUIPEMENT FIXE', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildInfoItem('Nom:', name)),
                      pw.Expanded(child: _buildInfoItem('Catégorie:', category)),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildInfoItem('Emplacement:', location)),
                      pw.Expanded(child: _buildInfoItem('Statut:', status.toUpperCase())),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // If USD, USD Components table
            if (isUSD && usdDetails.isNotEmpty) ...[
              pw.Text(
                'ÉTAT DES COMPOSANTS USD',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
              ),
              pw.SizedBox(height: 5),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.amber900),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3.5),
                  1: const pw.FlexColumnWidth(1.5),
                },
                headers: ['Composant USD', 'État (B / M)'],
                data: usdDetails.entries.map((e) => [_clean(e.key.toString()), _clean(e.value.toString())]).toList(),
              ),
              pw.SizedBox(height: 14),
            ],

            // Section 2: Historique de Maintenance
            pw.Text(
              'HISTORIQUE DE MAINTENANCE (${maintenanceRecords.length})',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
            ),
            pw.SizedBox(height: 5),
            if (maintenanceRecords.isEmpty)
              pw.Text('Aucune opération de maintenance enregistrée.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
            else
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: const pw.TextStyle(fontSize: 7.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2), // Date
                  1: const pw.FlexColumnWidth(1.1), // Type
                  2: const pw.FlexColumnWidth(3.0), // Description
                  3: const pw.FlexColumnWidth(1.5), // Responsable
                  4: const pw.FlexColumnWidth(1.5), // Prestataire
                  5: const pw.FlexColumnWidth(1.0), // Statut
                },
                headers: ['Date', 'Type', 'Description', 'Responsable', 'Prestataire', 'Statut'],
                data: maintenanceRecords.map((m) {
                  final date = _clean((m['maintenance_date'] as String?) ?? (m['date'] as String?) ?? '-');
                  final mType = _clean((m['maintenance_type'] as String?) ?? (m['type'] as String?) ?? '-');
                  final desc = _clean((m['description'] as String?) ?? '-');
                  final resp = _clean((m['responsible'] as String?) ?? '-');
                  final prov = _clean((m['provider'] as String?) ?? '-');
                  final stat = _clean((m['maintenance_status'] as String?) ?? (m['status'] as String?) ?? 'Terminé');
                  return [date, mType, desc, resp, prov, stat];
                }).toList(),
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Rapport_Equipement_${name.replaceAll(' ', '_')}.pdf',
    );
  }

  static pw.Widget _buildInfoItem(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('$label ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
        pw.Expanded(
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)),
        ),
      ],
    );
  }
}
