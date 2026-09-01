import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/app_export.dart';
import '../../../../services/supabase_service.dart';
import './equipment_tab_widget.dart';
import 'equipment_tab_widget.dart' show UserRole;

class MaintenanceTabWidget extends StatefulWidget {
  final String vehicleId;
  final String vehicleName;
  final UserRole userRole;

  const MaintenanceTabWidget({
    super.key,
    required this.vehicleId,
    this.vehicleName = '',
    this.userRole = UserRole.admin,
  });

  @override
  State<MaintenanceTabWidget> createState() => _MaintenanceTabWidgetState();
}

class _MaintenanceTabWidgetState extends State<MaintenanceTabWidget> {
  final _svc = SupabaseService.instance;
  List<Map<String, dynamic>> _maintenanceMaps = [];
  bool _isLoading = true;
  String? _errorMsg;
  RealtimeChannel? _channel;

  bool get _canEdit =>
      widget.userRole == UserRole.admin ||
      widget.userRole == UserRole.superAdmin;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = false}) async {
    if (showLoading || _maintenanceMaps.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMsg = null;
      });
    }
    try {
      final records = await _svc.getMaintenanceRecords(widget.vehicleId);
      if (mounted) {
        setState(() {
          _maintenanceMaps = records;
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
        .channel('maintenance_${widget.vehicleId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_records',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'vehicle_id',
            value: widget.vehicleId,
          ),
          callback: (_) => _loadData(),
        )
        .subscribe();
  }

  String _colorForType(String type) {
    switch (type) {
      case 'Préventive':
        return 'blue';
      case 'Vidange':
        return 'orange';
      case 'Corrective':
        return 'red';
      case 'Réparation':
        return 'red';
      case 'Inspection':
        return 'green';
      default:
        return 'blue';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMsg != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'error_outline',
              color: AppTheme.critical,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Erreur: $_errorMsg',
              style: GoogleFonts.ibmPlexSans(color: AppTheme.mutedText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: AppTheme.surfaceLight,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historique de maintenance',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkCharcoal,
                      ),
                    ),
                    Text(
                      '${_maintenanceMaps.length} opération(s) enregistrée(s)',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        color: AppTheme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              if (_canEdit)
                ElevatedButton.icon(
                  onPressed: () => _showAddMaintenanceSheet(),
                  icon: CustomIconWidget(
                    iconName: 'add',
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text('Ajouter'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    textStyle: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(height: 1, color: AppTheme.outlineVariantLight),
        Expanded(
          child: _maintenanceMaps.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: _maintenanceMaps.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final record = _maintenanceMaps[i];
                    final displayRecord = {
                      'id': record['id'],
                      'date': record['maintenance_date'] ?? '',
                      'type': record['maintenance_type'] ?? '',
                      'description': record['description'] ?? '',
                      'provider': record['provider'] ?? '',
                      'responsible': record['responsible'] ?? '',
                      'observation': record['observation'] ?? '',
                      'next_date': record['next_maintenance_date'] ?? '',
                      'status': record['maintenance_status'] ?? 'Terminé',
                      'typeColor': _colorForType(
                        record['maintenance_type'] ?? '',
                      ),
                    };
                    return _MaintenanceCard(
                      record: displayRecord,
                      canEdit: _canEdit,
                      onEdit: () => _showEditMaintenanceSheet(record),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomIconWidget(
            iconName: 'build_circle',
            color: AppTheme.mutedText,
            size: 72,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune opération de maintenance enregistrée',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkCharcoal,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Les opérations de maintenance apparaîtront ici',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              color: AppTheme.mutedText,
            ),
          ),
          if (_canEdit) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddMaintenanceSheet(),
              icon: CustomIconWidget(
                iconName: 'add',
                color: Colors.white,
                size: 18,
              ),
              label: const Text('Ajouter une maintenance'),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddMaintenanceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddMaintenanceSheet(
        userRole: widget.userRole,
        onSubmit: (data) async {
          Navigator.pop(ctx);
          try {
            await _svc.createMaintenanceRecord(
              vehicleId: widget.vehicleId,
              vehicleName: widget.vehicleName,
              maintenanceDate: data['date'] as String,
              maintenanceType: data['type'] as String,
              description: data['description'] as String,
              provider: data['provider'] as String? ?? '',
              responsible: data['responsible'] as String? ?? '',
              observation: data['observation'] as String? ?? '',
              nextMaintenanceDate: data['next_date'] as String?,
              maintenanceStatus: data['status'] as String? ?? 'Terminé',
            );
            await _loadData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Maintenance enregistrée avec succès',
                    style: GoogleFonts.ibmPlexSans(color: Colors.white),
                  ),
                  backgroundColor: AppTheme.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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

  void _showEditMaintenanceSheet(Map<String, dynamic> record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddMaintenanceSheet(
        userRole: widget.userRole,
        initialData: {
          'date': record['maintenance_date'] ?? '',
          'type': record['maintenance_type'] ?? 'Préventive',
          'description': record['description'] ?? '',
          'provider': record['provider'] ?? '',
          'responsible': record['responsible'] ?? '',
          'observation': record['observation'] ?? '',
          'next_date': record['next_maintenance_date'] ?? '',
          'status': record['maintenance_status'] ?? 'Terminé',
        },
        onSubmit: (data) async {
          Navigator.pop(ctx);
          try {
            await _svc.updateMaintenanceRecord(
              recordId: record['id'] as String,
              vehicleName: widget.vehicleName,
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
            await _loadData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Maintenance mise à jour',
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
}

// ── Maintenance Card ──────────────────────────────────────────────────────────
class _MaintenanceCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final bool canEdit;
  final VoidCallback onEdit;

  const _MaintenanceCard({
    required this.record,
    required this.canEdit,
    required this.onEdit,
  });

  Color _typeColor(String colorKey) {
    switch (colorKey) {
      case 'blue':
        return AppTheme.primary;
      case 'orange':
        return AppTheme.warning;
      case 'red':
        return AppTheme.critical;
      case 'green':
        return AppTheme.success;
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(record['typeColor'] as String? ?? 'blue');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariantLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withAlpha(15),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: color.withAlpha(40))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    record['type'] as String? ?? '',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: record['status'] as String? ?? 'Terminé'),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record['date'] as String? ?? '',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      color: AppTheme.mutedText,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
                if (canEdit)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onTap: onEdit,
                      child: CustomIconWidget(
                        iconName: 'edit',
                        color: AppTheme.mutedText,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['description'] as String? ?? '',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.darkCharcoal,
                  ),
                ),
                if ((record['next_date'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: 'event_available',
                    label: 'Prochaine maintenance',
                    value: record['next_date'] as String,
                  ),
                ],
                if ((record['provider'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: 'business',
                    label: 'Prestataire',
                    value: record['provider'] as String,
                  ),
                ],
                if ((record['responsible'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _InfoRow(
                    icon: 'person',
                    label: 'Responsable',
                    value: record['responsible'] as String,
                  ),
                ],
                if ((record['observation'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariantLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomIconWidget(
                          iconName: 'info_outline',
                          color: AppTheme.mutedText,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            record['observation'] as String,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 12,
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
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CustomIconWidget(iconName: icon, color: AppTheme.mutedText, size: 14),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            color: AppTheme.mutedText,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              color: AppTheme.darkCharcoal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Status Chip ───────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color _color() {
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

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withAlpha(22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withAlpha(60)),
      ),
      child: Text(
        status,
        style: GoogleFonts.ibmPlexSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
    );
  }
}

// ── Add/Edit Maintenance Sheet ────────────────────────────────────────────────
class _AddMaintenanceSheet extends StatefulWidget {
  final UserRole userRole;
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onSubmit;

  const _AddMaintenanceSheet({
    required this.userRole,
    this.initialData,
    required this.onSubmit,
  });

  @override
  State<_AddMaintenanceSheet> createState() => _AddMaintenanceSheetState();
}

class _AddMaintenanceSheetState extends State<_AddMaintenanceSheet> {
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
                      ? 'Modifier maintenance'
                      : 'Nouvelle maintenance',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
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
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Type de maintenance',
              ),
              items: [
                'Préventive',
                'Corrective',
                'Vidange',
                'Réparation',
                'Inspection',
              ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) =>
                  setState(() => _selectedType = v ?? 'Préventive'),
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CustomIconWidget(
                iconName: 'event_available',
                color: AppTheme.success,
                size: 20,
              ),
              title: Text(
                _nextDate == null
                    ? 'Prochaine maintenance: Non définie'
                    : 'Prochaine: ${_nextDate!.day.toString().padLeft(2, '0')}/${_nextDate!.month.toString().padLeft(2, '0')}/${_nextDate!.year}',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 14,
                  color: _nextDate == null ? AppTheme.mutedText : AppTheme.darkCharcoal,
                ),
              ),
              trailing: _nextDate != null
                  ? GestureDetector(
                      onTap: () => setState(() => _nextDate = null),
                      child: const Icon(Icons.close, size: 18),
                    )
                  : null,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _nextDate ?? _selectedDate.add(const Duration(days: 90)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2035),
                );
                if (picked != null) setState(() => _nextDate = picked);
              },
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
