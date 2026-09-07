import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:universal_html/html.dart' as html;

class PdfReportService {
  static final PdfReportService instance = PdfReportService._();
  PdfReportService._();

  /// Sanitize text to remove/replace emojis and characters outside Latin-1 to prevent Helvetica font crashes
  String _clean(String text) {
    if (text.isEmpty) return text;
    final buffer = StringBuffer();
    for (final char in text.runes) {
      if (char == 8212 || char == 8211) {
        buffer.write('-');
      } else if (char == 8216 || char == 8217) {
        buffer.write("'");
      } else if (char == 8220 || char == 8221) {
        buffer.write('"');
      } else if (char <= 255) {
        buffer.writeCharCode(char);
      } else {
        // Replace emojis or unsupported unicode with space
        buffer.write(' ');
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Robust PDF export / print handling for iOS Safari, Web and Mobile platforms
  Future<void> _exportPdf({
    required pw.Document pdf,
    required String filename,
  }) async {
    final Uint8List bytes = await pdf.save();

    if (kIsWeb) {
      bool isIOS = false;
      bool isSafari = false;
      try {
        final ua = html.window.navigator.userAgent.toLowerCase();
        isIOS = ua.contains('iphone') ||
            ua.contains('ipad') ||
            ua.contains('ipod') ||
            (ua.contains('macintosh') && (html.window.navigator.maxTouchPoints ?? 0) > 1);
        isSafari = ua.contains('safari') && !ua.contains('chrome');
      } catch (_) {}

      // On iOS Web / Safari Mobile:
      // Printing.layoutPdf fails because iframe printing is not supported on iOS Safari and popup windows are blocked.
      // Printing.sharePdf passes filename to anchor.download / navigator.share which triggers the native iOS share sheet (AirPrint / Save to Files).
      if (isIOS || isSafari) {
        try {
          final shared = await Printing.sharePdf(bytes: bytes, filename: filename);
          if (shared) return;
        } catch (_) {}

        // Fallback: direct Blob anchor download
        try {
          final blob = html.Blob([bytes], 'application/pdf');
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute('download', filename);
          html.document.body?.children.add(anchor);
          anchor.click();
          anchor.remove();
          html.Url.revokeObjectUrl(url);
          return;
        } catch (_) {}
      }

      // Desktop web (Chrome, Edge, Firefox):
      // Try Printing.layoutPdf first to show native browser print preview dialog
      try {
        await Printing.layoutPdf(
          onLayout: (format) async => bytes,
          name: filename,
        );
        return;
      } catch (_) {
        // Fallback to sharePdf or Blob download
        try {
          await Printing.sharePdf(bytes: bytes, filename: filename);
          return;
        } catch (_) {
          try {
            final blob = html.Blob([bytes], 'application/pdf');
            final url = html.Url.createObjectUrlFromBlob(blob);
            final anchor = html.AnchorElement(href: url)
              ..setAttribute('download', filename);
            html.document.body?.children.add(anchor);
            anchor.click();
            anchor.remove();
            html.Url.revokeObjectUrl(url);
            return;
          } catch (_) {}
        }
      }
      return;
    }

    // Native mobile platforms (Android APK, iOS native app)
    try {
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: filename,
      );
    } catch (_) {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    }
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

  bool _matchesDateFilter(String rawDate, dynamic filterMonthOrMonths, String filterYear) {
    final dateStr = rawDate.trim();
    final List<String> filterMonths = (filterMonthOrMonths is List<String>)
        ? filterMonthOrMonths
        : (filterMonthOrMonths is List ? List<String>.from(filterMonthOrMonths) : [filterMonthOrMonths?.toString() ?? 'Tous']);

    if (dateStr.isEmpty) {
      return (filterYear == 'Tous' && (filterMonths.isEmpty || filterMonths.contains('Tous')));
    }

    String? year;
    String? month;

    try {
      final dt = DateTime.parse(dateStr);
      year = dt.year.toString();
      month = dt.month.toString().padLeft(2, '0');
    } catch (_) {
      final parts = dateStr.split(RegExp(r'[\/\.\-\s]'));
      if (parts.length >= 3) {
        if (parts[0].length == 4) {
          year = parts[0];
          month = parts[1].padLeft(2, '0');
        } else if (parts[2].length == 4) {
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

    if (!filterMonths.contains('Tous') && filterMonths.isNotEmpty) {
      if (month != null) {
        if (!filterMonths.contains(month)) return false;
      } else {
        bool matchedAny = false;
        for (final m in filterMonths) {
          if (dateStr.contains('-$m-') || dateStr.contains('/$m/') || dateStr.contains('.$m.')) {
            matchedAny = true;
            break;
          }
        }
        if (!matchedAny) return false;
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
    dynamic filterMonth = 'Tous',
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

    // Filter maintenance records by year and multi-month
    final filteredMaintenance = maintenanceRecords.where((m) {
      final dateStr = (m['maintenance_date'] as String?) ?? (m['date'] as String?) ?? '';
      return _matchesDateFilter(dateStr, filterMonth, filterYear);
    }).toList();

    String maintHeaderTitle = 'HISTORIQUE DE MAINTENANCE (${filteredMaintenance.length})';
    final List<String> monthList = (filterMonth is List<String>)
        ? filterMonth
        : (filterMonth is List ? List<String>.from(filterMonth) : [filterMonth.toString()]);

    if (filterYear != 'Tous' || (!monthList.contains('Tous') && monthList.isNotEmpty)) {
      final filterParts = <String>[];
      if (!monthList.contains('Tous') && monthList.isNotEmpty) {
        const monthNames = {
          '01': 'Jan', '02': 'Fév', '03': 'Mar', '04': 'Avr',
          '05': 'Mai', '06': 'Juin', '07': 'Juil', '08': 'Août',
          '09': 'Sept', '10': 'Oct', '11': 'Nov', '12': 'Déc'
        };
        final labels = monthList.map((m) => monthNames[m] ?? m).join(', ');
        filterParts.add('Mois: $labels');
      }
      if (filterYear != 'Tous') filterParts.add('Année: $filterYear');
      maintHeaderTitle += ' [Filtre: ${filterParts.join(' - ')}]';
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

    await _exportPdf(
      pdf: pdf,
      filename: 'Rapport_Vehicule_${name.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Print or share fixed equipment technical sheet + maintenance history PDF
  Future<void> printFixedEquipmentPdf({
    required Map<String, dynamic> equipment,
    required List<Map<String, dynamic>> maintenanceRecords,
    dynamic filterMonth = 'Tous',
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
    if (rawUsd is String && rawUsd.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawUsd);
        if (decoded is Map) usdDetails = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    // Filter maintenance records by year and multi-month
    final filteredMaintenance = maintenanceRecords.where((m) {
      final dateStr = (m['maintenance_date'] as String?) ?? (m['date'] as String?) ?? '';
      return _matchesDateFilter(dateStr, filterMonth, filterYear);
    }).toList();

    String maintHeaderTitle = 'HISTORIQUE DE MAINTENANCE (${filteredMaintenance.length})';
    final List<String> monthList = (filterMonth is List<String>)
        ? filterMonth
        : (filterMonth is List ? List<String>.from(filterMonth) : [filterMonth.toString()]);

    if (filterYear != 'Tous' || (!monthList.contains('Tous') && monthList.isNotEmpty)) {
      final filterParts = <String>[];
      if (!monthList.contains('Tous') && monthList.isNotEmpty) {
        const monthNames = {
          '01': 'Jan', '02': 'Fév', '03': 'Mar', '04': 'Avr',
          '05': 'Mai', '06': 'Juin', '07': 'Juil', '08': 'Août',
          '09': 'Sept', '10': 'Oct', '11': 'Nov', '12': 'Déc'
        };
        final labels = monthList.map((m) => monthNames[m] ?? m).join(', ');
        filterParts.add('Mois: $labels');
      }
      if (filterYear != 'Tous') filterParts.add('Année: $filterYear');
      maintHeaderTitle += ' [Filtre: ${filterParts.join(' - ')}]';
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

            // Spacing for Maintenance History
            if (isUSD && usdDetails.isNotEmpty) pw.SizedBox(height: 10),

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

    await _exportPdf(
      pdf: pdf,
      filename: 'Rapport_Equipement_${name.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Print or share PV Divers PDF report (filtered by Month & Year)
  Future<void> printPvDiversPdf({
    required List<Map<String, dynamic>> pvList,
    dynamic filterMonth = 'Tous',
    String filterYear = 'Tous',
  }) async {
    final logoBytes = await _loadLogo();
    final pdf = pw.Document();
    final dateFormatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // Filter PV records by year and multi-month
    final filteredPv = pvList.where((pv) {
      final dateStr = (pv['date'] as String?) ?? '';
      return _matchesDateFilter(dateStr, filterMonth, filterYear);
    }).toList();

    String pvHeaderTitle = 'PROCÈS-VERBAUX DIVERS (${filteredPv.length})';
    final List<String> monthList = (filterMonth is List<String>)
        ? filterMonth
        : (filterMonth is List ? List<String>.from(filterMonth) : [filterMonth.toString()]);

    if (filterYear != 'Tous' || (!monthList.contains('Tous') && monthList.isNotEmpty)) {
      final filterParts = <String>[];
      if (!monthList.contains('Tous') && monthList.isNotEmpty) {
        const monthNames = {
          '01': 'Jan', '02': 'Fév', '03': 'Mar', '04': 'Avr',
          '05': 'Mai', '06': 'Juin', '07': 'Juil', '08': 'Août',
          '09': 'Sept', '10': 'Oct', '11': 'Nov', '12': 'Déc'
        };
        final labels = monthList.map((m) => monthNames[m] ?? m).join(', ');
        filterParts.add('Mois: $labels');
      }
      if (filterYear != 'Tous') filterParts.add('Année: $filterYear');
      pvHeaderTitle += ' [Filtre: ${filterParts.join(' - ')}]';
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

    await _exportPdf(
      pdf: pdf,
      filename: 'Rapport_PV_Divers.pdf',
    );
  }

  /// Print summary / inventory list of fixed equipment (e.g. all USD or all Pompe)
  Future<void> printFixedEquipmentListPdf({
    required String categoryTitle,
    required List<Map<String, dynamic>> equipments,
    String filterStatus = 'Tous',
  }) async {
    final logoBytes = await _loadLogo();
    final pdf = pw.Document();
    final dateFormatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final filtered = filterStatus == 'Tous'
        ? equipments
        : equipments.where((e) => (e['status'] as String?) == filterStatus).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoBytes.isNotEmpty)
                    pw.Image(pw.MemoryImage(logoBytes), width: 55, height: 55)
                  else
                    pw.Container(width: 55, height: 55),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'SONATRACH - TRC RTH',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.amber900,
                        ),
                      ),
                      pw.Text(
                        'Direction Régionale Transport Hydrocarbures',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Édité le: $dateFormatted',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Divider(thickness: 1.5, color: PdfColors.amber900),
              pw.SizedBox(height: 5),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Sanad Sonatrach TRC RTH - Inventaire Officiel', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
              pw.Text('Page ${context.pageNumber} sur ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                'RÉCAPITULATIF DES ÉQUIPEMENTS FIXES — ${_clean(categoryTitle).toUpperCase()} (${filtered.length})',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.6), // N°
                1: const pw.FlexColumnWidth(2.5), // Nom
                2: const pw.FlexColumnWidth(1.8), // Emplacement
                3: const pw.FlexColumnWidth(1.4), // Statut
                4: const pw.FlexColumnWidth(1.5), // Dernière Inspection
                5: const pw.FlexColumnWidth(3.0), // Détails / Composants
              },
              headers: ['N°', 'Nom Équipement', 'Emplacement', 'Statut', 'Dernière Insp.', 'Détails / Composants'],
              data: [
                for (int i = 0; i < filtered.length; i++) ...[
                  () {
                    final item = filtered[i];
                    final name = _clean((item['name'] as String?) ?? '-');
                    final loc = _clean((item['location'] as String?) ?? '-');
                    final st = _clean((item['status'] as String?) ?? 'operational');
                    final insp = _clean((item['last_inspection'] as String?) ?? (item['lastInspection'] as String?) ?? '-');

                    String detailsStr = '-';
                    final rawUsd = item['usd_details'];
                    Map<String, dynamic> parsedUsd = {};
                    if (rawUsd is Map<String, dynamic>) parsedUsd = rawUsd;
                    if (rawUsd is Map) parsedUsd = Map<String, dynamic>.from(rawUsd);
                    if (rawUsd is String && rawUsd.isNotEmpty) {
                      try {
                        final d = jsonDecode(rawUsd);
                        if (d is Map) parsedUsd = Map<String, dynamic>.from(d);
                      } catch (_) {}
                    }
                    if (parsedUsd.isNotEmpty) {
                      detailsStr = parsedUsd.entries.map((e) => '${_clean(e.key)}: ${e.value}').join(', ');
                    }

                    return [
                      '${i + 1}',
                      name,
                      loc,
                      st == 'operational' ? 'Opérationnel' : (st == 'maintenance' ? 'Maintenance' : 'Hors Service'),
                      insp,
                      detailsStr,
                    ];
                  }()
                ],
              ],
            ),
          ];
        },
      ),
    );

    await _exportPdf(
      pdf: pdf,
      filename: 'Inventaire_${_clean(categoryTitle).replaceAll(' ', '_')}.pdf',
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
