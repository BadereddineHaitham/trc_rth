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

  String _formatDateValue(dynamic val) {
    if (val == null) return 'Non renseigné';
    final str = val.toString().trim();
    if (str.isEmpty || str == '-' || str == 'null') return 'Non renseigné';
    try {
      final dt = DateTime.parse(str);
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return str;
    }
  }

  bool _matchesDateFilter(String rawDate, String filterMonth, String filterYear) {
    final dateStr = rawDate.trim();
    if (dateStr.isEmpty) {
      return (filterYear == 'Tous' && filterMonth == 'Tous');
    }

    String? year;
    String? month;

    // Try parsing ISO or YYYY-MM-DD
    try {
      final dt = DateTime.parse(dateStr);
      year = dt.year.toString();
      month = dt.month.toString().padLeft(2, '0');
    } catch (_) {
      // Split by common delimiters: -, /, .
      final parts = dateStr.split(RegExp(r'[\/\.\-\s]'));
      if (parts.length >= 3) {
        if (parts[0].length == 4) {
          // YYYY-MM-DD or YYYY/MM/DD
          year = parts[0];
          month = parts[1].padLeft(2, '0');
        } else if (parts[2].length == 4) {
          // DD-MM-YYYY or DD/MM/YYYY
          year = parts[2];
          month = parts[1].padLeft(2, '0');
        }
      }
    }

    if (filterYear != 'Tous' && filterYear.isNotEmpty) {
      if (year != null) {
        if (year != filterYear) return false;
      } else {
        if (!dateStr.contains(filterYear)) return false;
      }
    }

    if (filterMonth != 'Tous' && filterMonth.isNotEmpty) {
      if (month != null) {
        if (month != filterMonth) return false;
      } else {
        final monthDash = '-$filterMonth-';
        final monthSlash = '/$filterMonth/';
        final monthDot = '.$filterMonth.';
        if (!dateStr.contains(monthDash) &&
            !dateStr.contains(monthSlash) &&
            !dateStr.contains(monthDot)) {
          return false;
        }
      }
    }

    return true;
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
    String filterMonth = 'Tous',
    String filterYear = 'Tous',
  }) async {
    final logoBytes = await _loadLogo();
    final pdf = pw.Document();

    final name = _clean((vehicle['name'] as String?) ?? 'Véhicule');
    final type = _clean((vehicle['type'] as String?) ?? (vehicle['vehicle_type'] as String?) ?? 'Spécialisé');
    final matricule = _clean((vehicle['matricule'] as String?) ?? (vehicle['id'] as String?) ?? '-');
    final affectation = _clean((vehicle['affectation'] as String?) ?? '-');
    final status = _clean((vehicle['status'] as String?) ?? 'operational');

    final rawInsurance = vehicle['insurance_expiry'] ??
        vehicle['insuranceExpiry'] ??
        vehicle['insurance_start'] ??
        vehicle['insuranceStart'] ??
        vehicle['insurance'];

    final rawInspection = vehicle['inspection_expiry'] ??
        vehicle['inspectionExpiry'] ??
        vehicle['inspection'];

    final rawOilChange = vehicle['oil_change_date'] ??
        vehicle['oilChange'] ??
        vehicle['oil_change'];

    final insurance = _clean(_formatDateValue(rawInsurance));
    final inspection = _clean(_formatDateValue(rawInspection));
    final oilChange = _clean(_formatDateValue(rawOilChange));

    final dateFormatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // Filter maintenance records by year and month using robust matcher
    final filteredMaintenance = maintenanceRecords.where((m) {
      final dateStr = (m['maintenance_date'] as String?) ?? (m['date'] as String?) ?? '';
      return _matchesDateFilter(dateStr, filterMonth, filterYear);
    }).toList();

    String maintHeaderTitle = 'HISTORIQUE DE MAINTENANCE (${filteredMaintenance.length})';
    if (filterYear != 'Tous' || filterMonth != 'Tous') {
      final filterParts = <String>[];
      if (filterMonth != 'Tous') filterParts.add('Mois: $filterMonth');
      if (filterYear != 'Tous') filterParts.add('Année: $filterYear');
      maintHeaderTitle += ' [Filtre: ${filterParts.join(', ')}]';
    }

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
            // Page 1: Vehicle General Info & Equipment List
            pw.Center(
              child: pw.Text(
                'FICHE TECHNIQUE VÉHICULE & ARMEMENT',
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
                      pw.Expanded(child: _buildInfoItem('Dernière Vidange:', oilChange)),
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

            // Force New Page for Maintenance History when there is an equipment section
            if (equipmentList.isNotEmpty) pw.NewPage(),

            // Section 2: Historique de Maintenance
            pw.Text(
              maintHeaderTitle,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
            ),
            pw.SizedBox(height: 5),
            if (filteredMaintenance.isEmpty)
              pw.Text('Aucune opération de maintenance correspondant aux critères de recherche.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
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
                data: filteredMaintenance.map((m) {
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
    String filterMonth = 'Tous',
    String filterYear = 'Tous',
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

    // Filter maintenance records by year and month using robust matcher
    final filteredMaintenance = maintenanceRecords.where((m) {
      final dateStr = (m['maintenance_date'] as String?) ?? (m['date'] as String?) ?? '';
      return _matchesDateFilter(dateStr, filterMonth, filterYear);
    }).toList();

    String maintHeaderTitle = 'HISTORIQUE DE MAINTENANCE (${filteredMaintenance.length})';
    if (filterYear != 'Tous' || filterMonth != 'Tous') {
      final filterParts = <String>[];
      if (filterMonth != 'Tous') filterParts.add('Mois: $filterMonth');
      if (filterYear != 'Tous') filterParts.add('Année: $filterYear');
      maintHeaderTitle += ' [Filtre: ${filterParts.join(', ')}]';
    }

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

            // Force New Page for Maintenance History if there is USD component details
            if (isUSD && usdDetails.isNotEmpty) pw.NewPage(),

            // Section 2: Historique de Maintenance
            pw.Text(
              maintHeaderTitle,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
            ),
            pw.SizedBox(height: 5),
            if (filteredMaintenance.isEmpty)
              pw.Text('Aucune opération de maintenance correspondant aux critères de recherche.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
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
                data: filteredMaintenance.map((m) {
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

  /// Print or share PV Divers PDF report (filtered by Month & Year)
  Future<void> printPvDiversPdf({
    required List<Map<String, dynamic>> pvList,
    String filterMonth = 'Tous',
    String filterYear = 'Tous',
  }) async {
    final logoBytes = await _loadLogo();
    final pdf = pw.Document();
    final dateFormatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // Filter PV records by year and month using robust matcher
    final filteredPv = pvList.where((pv) {
      final dateStr = (pv['date'] as String?) ?? '';
      return _matchesDateFilter(dateStr, filterMonth, filterYear);
    }).toList();

    String pvHeaderTitle = 'PROCÈS-VERBAUX DIVERS (${filteredPv.length})';
    if (filterYear != 'Tous' || filterMonth != 'Tous') {
      final filterParts = <String>[];
      if (filterMonth != 'Tous') filterParts.add('Mois: $filterMonth');
      if (filterYear != 'Tous') filterParts.add('Année: $filterYear');
      pvHeaderTitle += ' [Filtre: ${filterParts.join(', ')}]';
    }

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
            pw.Center(
              child: pw.Text(
                'RAPPORT PV DIVERS',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              pvHeaderTitle,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
            ),
            pw.SizedBox(height: 6),
            if (filteredPv.isEmpty)
              pw.Text('Aucun PV divers correspondant aux critères de recherche.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
            else
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.amber900),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.5), // Date
                  1: const pw.FlexColumnWidth(2.0), // Equipe
                  2: const pw.FlexColumnWidth(4.5), // Description
                  3: const pw.FlexColumnWidth(1.5), // Fichier PDF
                },
                headers: ['Date', 'Équipe', 'Description', 'Fichier PDF'],
                data: filteredPv.map((pv) {
                  final date = _clean((pv['date'] as String?) ?? '-');
                  final equipe = _clean((pv['equipe'] as String?) ?? (pv['team'] as String?) ?? '-');
                  final desc = _clean((pv['description'] as String?) ?? '-');
                  final pdfUrl = (pv['pdf_url'] as String?) ?? '';
                  final hasPdf = pdfUrl.isNotEmpty ? 'Oui (Joint)' : 'Non';
                  return [date, equipe, desc, hasPdf];
                }).toList(),
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Rapport_PV_Divers.pdf',
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
