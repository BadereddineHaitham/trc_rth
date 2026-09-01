import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/app_export.dart';
import '../../../../services/pdf_report_service.dart';
import '../../../../services/supabase_service.dart';

class FixedEquipmentMaintenanceModal extends StatefulWidget {
  final Map<String, dynamic> equipment;
  final bool canEdit;
  final VoidCallback onDataChanged;

  const FixedEquipmentMaintenanceModal({
    super.key,
    required this.equipment,
    required this.canEdit,
    required this.onDataChanged,
  });

  @override
  State<FixedEquipmentMaintenanceModal> createState() =>
      _FixedEquipmentMaintenanceModalState();
}

class _FixedEquipmentMaintenanceModalState
    extends State<FixedEquipmentMaintenanceModal> {
  final _svc = SupabaseService.instance;
  List<Map<String, dynamic>> _maintenanceRecords = [];
  bool _isLoading = true;
  String? _errorMsg;
  RealtimeChannel? _channel;

  String _maintFilterMonth = 'Tous';
  String _maintFilterYear = 'Tous';

  String get _equipmentId => widget.equipment['id'] as String;
  String get _name => widget.equipment['name'] as String? ?? 'Équipement Fixe';
  String get _category => widget.equipment['category'] as String? ?? 'Général';
  bool get _isUSD => _category.toUpperCase().contains('USD');

  Map<String, dynamic> get _usdDetails {
    final raw = widget.equipment['usd_details'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  @override
  void initState() {
    super.initState();
    _loadMaintenance();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadMaintenance() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final records = await _svc.getMaintenanceRecordsForEquipment(_equipmentId);
      if (mounted) {
        setState(() {
          _maintenanceRecords = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _subscribeRealtime() {
    _channel = _svc.client
        .channel('fixed_equip_maint_$_equipmentId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_records',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'equipment_id',
            value: _equipmentId,
          ),
          callback: (_) => _loadMaintenance(),
        )
        .subscribe();
  }

  void _showAddMaintenanceSheet() {
    _openMaintenanceSheet(null);
  }

  void _showEditMaintenanceSheet(Map<String, dynamic> rec) {
    _openMaintenanceSheet(rec);
  }

  void _openMaintenanceSheet(Map<String, dynamic>? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddFixedMaintenanceSheet(
        equipmentName: _name,
        initialData: existing == null
            ? null
            : {
                'date': existing['maintenance_date'] ?? '',
                'type': existing['maintenance_type'] ?? 'Préventive',
                'status': existing['maintenance_status'] ?? 'Terminé',
                'description': existing['description'] ?? '',
                'provider': existing['provider'] ?? '',
                'responsible': existing['responsible'] ?? '',
                'observation': existing['observation'] ?? '',
                'next_date': existing['next_maintenance_date'] ?? '',
              },
        onSubmit: (data) async {
          Navigator.pop(ctx);
          try {
            if (existing == null) {
              await _svc.createMaintenanceRecord(
                equipmentId: _equipmentId,
                vehicleName: _name,
                maintenanceDate: data['date'] as String,
                maintenanceType: data['type'] as String,
                description: data['description'] as String,
                provider: data['provider'] as String? ?? '',
                responsible: data['responsible'] as String? ?? '',
                observation: data['observation'] as String? ?? '',
                nextMaintenanceDate: data['next_date'] as String?,
                maintenanceStatus: data['status'] as String? ?? 'Terminé',
              );
            } else {
              await _svc.updateMaintenanceRecord(
                recordId: existing['id'] as String,
                vehicleName: _name,
                data: {
                  'maintenance_date': data['date'],
                  'maintenance_type': data['type'],
                  'description': data['description'],
                  'provider': data['provider'],
                  'responsible': data['responsible'],
                  'observation': data['observation'],
                  'maintenance_status': data['status'] ?? 'Terminé',
                  if ((data['next_date'] as String? ?? '').isNotEmpty)
                    'next_maintenance_date': data['next_date'],
                },
              );
            }
            await _loadMaintenance();
            widget.onDataChanged();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    existing == null
                        ? 'Maintenance enregistrée pour "$_name"'
                        : 'Maintenance mise à jour',
                    style: GoogleFonts.ibmPlexSans(color: Colors.white),
                  ),
                  backgroundColor: AppTheme.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Erreur: $e',
                    style: GoogleFonts.ibmPlexSans(color: Colors.white),
                  ),
                  backgroundColor: AppTheme.critical,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteMaintenanceRecord(Map<String, dynamic> rec) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la maintenance'),
        content: Text(
          'Supprimer cet enregistrement de maintenance ("${rec['description'] ?? ''}")  ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _svc.deleteMaintenanceRecord(rec['id'] as String);
      await _loadMaintenance();
      widget.onDataChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Maintenance supprimée',
              style: GoogleFonts.ibmPlexSans(color: Colors.white),
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.critical,
          ),
        );
      }
    }
  }

  Future<void> _printFixedEquipmentReport() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Génération du rapport PDF en cours...'),
          duration: Duration(seconds: 2),
        ),
      );
      await PdfReportService.instance.printFixedEquipmentPdf(
        equipment: widget.equipment,
        maintenanceRecords: _maintenanceRecords,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur génération PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.outlineVariantLight),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isUSD
                        ? AppTheme.primary.withAlpha(20)
                        : AppTheme.success.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: CustomIconWidget(
                    iconName: _isUSD ? 'shield' : 'settings',
                    color: _isUSD ? AppTheme.primary : AppTheme.success,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkCharcoal,
                        ),
                      ),
                      Text(
                        'Équipement Fixe — $_category',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 12,
                          color: AppTheme.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.print_outlined, color: AppTheme.primary),
                  onPressed: _printFixedEquipmentReport,
                  tooltip: 'Imprimer / Exporter PDF',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // If USD equipment, display component condition state grid
                  if (_isUSD) ...[
                    _buildUSDComponentsSection(),
                    const SizedBox(height: 24),
                  ],

                  // Maintenance section header
                  Row(
                    children: [
                      Text(
                        'Historique de maintenance',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkCharcoal,
                        ),
                      ),
                      const Spacer(),
                      if (widget.canEdit)
                        ElevatedButton.icon(
                          onPressed: _showAddMaintenanceSheet,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Ajouter'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            textStyle: GoogleFonts.ibmPlexSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Month & Year Filter Bar
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariantLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.outlineVariantLight),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _maintFilterMonth,
                              isExpanded: true,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 12,
                                color: AppTheme.darkCharcoal,
                                fontWeight: FontWeight.w600,
                              ),
                              icon: const Icon(Icons.calendar_month, size: 16, color: AppTheme.primary),
                              items: const [
                                DropdownMenuItem(value: 'Tous', child: Text('Tous les mois')),
                                DropdownMenuItem(value: '01', child: Text('Janvier')),
                                DropdownMenuItem(value: '02', child: Text('Février')),
                                DropdownMenuItem(value: '03', child: Text('Mars')),
                                DropdownMenuItem(value: '04', child: Text('Avril')),
                                DropdownMenuItem(value: '05', child: Text('Mai')),
                                DropdownMenuItem(value: '06', child: Text('Juin')),
                                DropdownMenuItem(value: '07', child: Text('Juillet')),
                                DropdownMenuItem(value: '08', child: Text('Août')),
                                DropdownMenuItem(value: '09', child: Text('Septembre')),
                                DropdownMenuItem(value: '10', child: Text('Octobre')),
                                DropdownMenuItem(value: '11', child: Text('Novembre')),
                                DropdownMenuItem(value: '12', child: Text('Décembre')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _maintFilterMonth = val);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 110,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariantLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.outlineVariantLight),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _maintFilterYear,
                            isExpanded: true,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 12,
                              color: AppTheme.darkCharcoal,
                              fontWeight: FontWeight.w600,
                            ),
                            icon: const Icon(Icons.date_range, size: 16, color: AppTheme.primary),
                            items: ['Tous', for (int y = 2035; y >= 2015; y--) y.toString()].map((y) {
                              return DropdownMenuItem<String>(
                                value: y,
                                child: Text(y == 'Tous' ? 'Toutes' : y),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _maintFilterYear = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_errorMsg != null)
                    Text(
                      'Erreur: $_errorMsg',
                      style: GoogleFonts.ibmPlexSans(color: AppTheme.critical),
                    )
                  else () {
                    final filteredRecords = _maintenanceRecords.where((rec) {
                      final dateStr = (rec['maintenance_date'] as String?) ?? (rec['date'] as String?) ?? '';
                      if (_maintFilterYear != 'Tous') {
                        if (!dateStr.startsWith(_maintFilterYear)) return false;
                      }
                      if (_maintFilterMonth != 'Tous') {
                        final parts = dateStr.split('-');
                        if (parts.length >= 2) {
                          if (parts[1] != _maintFilterMonth) return false;
                        }
                      }
                      return true;
                    }).toList();

                    if (filteredRecords.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariantLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Aucune maintenance enregistrée pour cet équipement.',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 13,
                            color: AppTheme.mutedText,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredRecords.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final rec = filteredRecords[i];
                        final type = rec['maintenance_type'] as String? ?? 'Préventive';
                        final date = rec['maintenance_date'] as String? ?? '';
                        final desc = rec['description'] as String? ?? '';
                        final status = rec['maintenance_status'] as String? ?? 'Terminé';
                        final provider = rec['provider'] as String? ?? '';
                        final responsible = rec['responsible'] as String? ?? '';
                        final observation = rec['observation'] as String? ?? '';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.outlineVariantLight,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row: type badge + date + action icons
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withAlpha(20),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      type,
                                      style: GoogleFonts.ibmPlexSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Status chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status).withAlpha(22),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: _statusColor(status).withAlpha(60)),
                                    ),
                                    child: Text(
                                      status,
                                      style: GoogleFonts.ibmPlexSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: _statusColor(status),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    date,
                                    style: GoogleFonts.ibmPlexMono(
                                      fontSize: 11,
                                      color: AppTheme.mutedText,
                                    ),
                                  ),
                                  if (widget.canEdit) ...[
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => _showEditMaintenanceSheet(rec),
                                      child: const Padding(
                                        padding: EdgeInsets.all(2),
                                        child: Icon(
                                          Icons.edit_outlined,
                                          size: 17,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    GestureDetector(
                                      onTap: () => _deleteMaintenanceRecord(rec),
                                      child: const Padding(
                                        padding: EdgeInsets.all(2),
                                        child: Icon(
                                          Icons.delete_outline,
                                          size: 17,
                                          color: AppTheme.critical,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Description
                              Text(
                                desc,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.darkCharcoal,
                                ),
                              ),
                              if (responsible.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 13, color: AppTheme.mutedText),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Responsable: ',
                                      style: GoogleFonts.ibmPlexSans(
                                        fontSize: 11,
                                        color: AppTheme.mutedText,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        responsible,
                                        style: GoogleFonts.ibmPlexSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.darkCharcoal,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (provider.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.business_outlined, size: 13, color: AppTheme.mutedText),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Prestataire: ',
                                      style: GoogleFonts.ibmPlexSans(
                                        fontSize: 11,
                                        color: AppTheme.mutedText,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        provider,
                                        style: GoogleFonts.ibmPlexSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.darkCharcoal,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (observation.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceVariantLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.info_outline, size: 13, color: AppTheme.mutedText),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          observation,
                                          style: GoogleFonts.ibmPlexSans(
                                            fontSize: 11,
                                            color: AppTheme.mutedText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  }(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'En cours':
        return AppTheme.warning;
      case 'Planifié':
        return AppTheme.primary;
      case 'Annulé':
        return AppTheme.critical;
      default:
        return AppTheme.success;
    }
  }

  int _usdTabCategoryIndex = 0; // 0 = LES VANNES, 1 = DIVERS

  Future<void> _updateComponentState(String itemKey, String newState) async {
    if (!widget.canEdit) return;
    try {
      final updatedDetails = Map<String, dynamic>.from(_usdDetails);
      updatedDetails[itemKey] = newState;
      await _svc.updateFixedEquipment(
        id: _equipmentId,
        data: {'usd_details': updatedDetails},
      );
      widget.equipment['usd_details'] = updatedDetails;
      if (mounted) setState(() {});
      widget.onDataChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur mise à jour: $e'),
            backgroundColor: AppTheme.critical,
          ),
        );
      }
    }
  }

  Widget _buildUSDComponentsSection() {
    final details = _usdDetails;

    // Categorized lists
    final vannesList = [
      'Vanne Entrée USD',
      'Vanne Sortie USD',
      'Vannes Entrée 1/4 tours — Unité A',
      'Vannes Entrée 1/4 tours — Unité B',
      'Vannes Sortie 1/4 tours — Unité A',
      'Vannes Sortie 1/4 tours — Unité B',
      'Vanne Régulatrice',
      'Vanne de remplissage et vidange émulseur — Unité A',
      'Vanne de remplissage et vidange émulseur — Unité B',
      'Vanne de remplissage et vidange eau — Unité A',
      'Vanne de remplissage et vidange eau — Unité B',
      'Vannes de purge ligne d\'interconnexion — Unité A',
      'Vannes de purge ligne d\'interconnexion — Unité B',
    ];

    final diversList = [
      'État D\'Unité A',
      'État D\'Unité B',
      'Filtre',
      'Les Manomètres',
      'Clapet anti-retour',
      'Autre',
    ];

    final currentList = _usdTabCategoryIndex == 0 ? vannesList : diversList;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariantLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomIconWidget(
                iconName: 'checklist',
                color: AppTheme.primary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'État des Composants USD (B / M)',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkCharcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Category Switcher
          Row(
            children: [
              Expanded(
                child: _buildModalCategoryBtn(
                  index: 0,
                  title: 'LES VANNES (${vannesList.length})',
                  icon: 'water_drop',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModalCategoryBtn(
                  index: 1,
                  title: 'DIVERS (${diversList.length})',
                  icon: 'tune',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...currentList.map(
            (item) => _buildItemStateRow(
              item,
              details[item] as String? ?? 'B',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalCategoryBtn({
    required int index,
    required String title,
    required String icon,
  }) {
    final isSelected = _usdTabCategoryIndex == index;
    return InkWell(
      onTap: () => setState(() => _usdTabCategoryIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.outlineVariantLight,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: icon,
              color: isSelected ? Colors.white : AppTheme.mutedText,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.darkCharcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemStateRow(String label, String state) {
    final isGood = state.toUpperCase() == 'B';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                color: AppTheme.darkCharcoal,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (widget.canEdit)
            Row(
              children: [
                GestureDetector(
                  onTap: () => _updateComponentState(label, 'B'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isGood ? AppTheme.success : Colors.grey.shade200,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                    ),
                    child: Text(
                      'B',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isGood ? Colors.white : AppTheme.mutedText,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _updateComponentState(label, 'M'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: !isGood ? AppTheme.critical : Colors.grey.shade200,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                    ),
                    child: Text(
                      'M',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: !isGood ? Colors.white : AppTheme.mutedText,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isGood ? AppTheme.successContainer : AppTheme.criticalContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isGood ? AppTheme.success.withAlpha(80) : AppTheme.critical.withAlpha(80),
                ),
              ),
              child: Text(
                isGood ? 'B' : 'M',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isGood ? AppTheme.success : AppTheme.critical,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Add/Edit Maintenance Sheet for Fixed Equipment ────────────────────────────
class _AddFixedMaintenanceSheet extends StatefulWidget {
  final String equipmentName;
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onSubmit;

  const _AddFixedMaintenanceSheet({
    required this.equipmentName,
    this.initialData,
    required this.onSubmit,
  });

  @override
  State<_AddFixedMaintenanceSheet> createState() =>
      _AddFixedMaintenanceSheetState();
}

class _AddFixedMaintenanceSheetState
    extends State<_AddFixedMaintenanceSheet> {
  final _descCtrl = TextEditingController();
  final _providerCtrl = TextEditingController();
  final _responsibleCtrl = TextEditingController();
  final _observationCtrl = TextEditingController();
  String _selectedType = 'Préventive';
  String _selectedStatus = 'Terminé';
  DateTime _selectedDate = DateTime.now();
  DateTime? _nextDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final d = widget.initialData!;
      _descCtrl.text = d['description'] as String? ?? '';
      _providerCtrl.text = d['provider'] as String? ?? '';
      _responsibleCtrl.text = d['responsible'] as String? ?? '';
      _observationCtrl.text = d['observation'] as String? ?? '';
      _selectedType = d['type'] as String? ?? 'Préventive';
      _selectedStatus = d['status'] as String? ?? 'Terminé';
      final dateStr = d['date'] as String? ?? '';
      if (dateStr.isNotEmpty) {
        try { _selectedDate = DateTime.parse(dateStr); } catch (_) {}
      }
      final nextStr = d['next_date'] as String? ?? '';
      if (nextStr.isNotEmpty) {
        try { _nextDate = DateTime.parse(nextStr); } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _providerCtrl.dispose();
    _responsibleCtrl.dispose();
    _observationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  widget.initialData != null
                      ? 'Modifier maintenance — ${widget.equipmentName}'
                      : 'Nouvelle maintenance — ${widget.equipmentName}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkCharcoal,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: const InputDecoration(labelText: 'Type de maintenance'),
              items: [
                'Préventive',
                'Curative',
                'Vidange',
                'Réparation',
                'Inspection',
              ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _selectedType = v ?? 'Préventive'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CustomIconWidget(
                iconName: 'calendar_today',
                color: AppTheme.primary,
                size: 20,
              ),
              title: Text(
                'Date: ${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                style: GoogleFonts.ibmPlexSans(fontSize: 14),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(labelText: 'Statut'),
              items: ['Terminé', 'En cours', 'Planifié', 'Annulé']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedStatus = v ?? 'Terminé'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description *'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _providerCtrl,
              decoration: const InputDecoration(labelText: 'Prestataire'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _responsibleCtrl,
              decoration: const InputDecoration(labelText: 'Responsable'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _observationCtrl,
              decoration: const InputDecoration(labelText: 'Observation'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving || _descCtrl.text.trim().isEmpty
                    ? null
                    : () {
                        setState(() => _saving = true);
                        widget.onSubmit({
                          'date':
                              '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                          'type': _selectedType,
                          'status': _selectedStatus,
                          'next_date': _nextDate == null
                              ? ''
                              : '${_nextDate!.year}-${_nextDate!.month.toString().padLeft(2, '0')}-${_nextDate!.day.toString().padLeft(2, '0')}',
                          'description': _descCtrl.text.trim(),
                          'provider': _providerCtrl.text.trim(),
                          'responsible': _responsibleCtrl.text.trim(),
                          'observation': _observationCtrl.text.trim(),
                        });
                      },
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
