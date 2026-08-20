import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_export.dart';
import '../../../services/supabase_service.dart';
import './widgets/equipment_tab_widget.dart';
import './widgets/fire_agents_tab_widget.dart';
import './widgets/maintenance_tab_widget.dart';
import './widgets/vehicle_info_tab_widget.dart';

class VehicleDetailsScreen extends StatefulWidget {
  final String vehicleId;
  final String role;

  const VehicleDetailsScreen({
    super.key,
    required this.vehicleId,
    this.role = 'User',
  });

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _svc = SupabaseService.instance;

  Map<String, dynamic> _vehicleData = {};
  bool _isLoading = true;
  String? _errorMsg;
  RealtimeChannel? _channel;

  bool get _canEdit => widget.role == 'Super Admin' || widget.role == 'Admin';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadVehicle();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadVehicle() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final data = await _svc.getVehicleById(widget.vehicleId);
      if (mounted) {
        setState(() {
          _vehicleData = data ?? {};
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
        .channel('vehicle_detail_${widget.vehicleId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vehicles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.vehicleId,
          ),
          callback: (_) => _loadVehicle(),
        )
        .subscribe();
  }

  // Map DB snake_case to display keys
  Map<String, dynamic> get _displayData => {
    'id': _vehicleData['id'] ?? widget.vehicleId,
    'name': _vehicleData['name'] ?? '',
    'type': _vehicleData['vehicle_type'] ?? '',
    'matricule': _vehicleData['matricule'] ?? '',
    'status': _vehicleData['status'] ?? 'operational',
    'insuranceStart': _vehicleData['insurance_start'] ?? '',
    'insuranceExpiry': _vehicleData['insurance_expiry'] ?? '',
    'inspectionExpiry': _vehicleData['inspection_expiry'] ?? '',
    'oilChange': _vehicleData['oil_change_date'] ?? '',
    'generalRemark': _vehicleData['general_remark'] ?? '',
    'water': _vehicleData['water_capacity'] ?? '',
    'emulsifier': _vehicleData['emulsifier_capacity'] ?? '',
    'powder': _vehicleData['powder_capacity'] ?? '',
    'water_capacity': _vehicleData['water_capacity'] ?? '',
    'emulsifier_capacity': _vehicleData['emulsifier_capacity'] ?? '',
    'powder_capacity': _vehicleData['powder_capacity'] ?? '',
    'pump_flow_water': _vehicleData['pump_flow_water'] ?? '',
    'pump_flow_emulsifier': _vehicleData['pump_flow_emulsifier'] ?? '',
    'pump_flow_powder': _vehicleData['pump_flow_powder'] ?? '',
    'pumpFlowWater': _vehicleData['pump_flow_water'] ?? '',
    'pumpFlowEmulsifier': _vehicleData['pump_flow_emulsifier'] ?? '',
    'pumpFlowPowder': _vehicleData['pump_flow_powder'] ?? '',
    'cannon_range': _vehicleData['cannon_range'] ?? '',
    'cannonRange': _vehicleData['cannon_range'] ?? '',
    'battery': _vehicleData['battery'] ?? '',
    'wheelRef': _vehicleData['wheel_ref'] ?? '',
    'affectation': _vehicleData['affectation'] ?? '',
    'parc': _vehicleData['parc_name'] ?? _vehicleData['parc'] ?? (_vehicleData['parks'] is Map ? _vehicleData['parks']['name'] : null) ?? '',
    'parc_name': _vehicleData['parc_name'] ?? _vehicleData['parc'] ?? '',
    'missingEquipment': _vehicleData['missing_equipment_count'] ?? 0,
  };

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditVehicleSheet(
        vehicle: _displayData,
        onSave: (updated) async {
          try {
            await _svc.updateVehicle(
              vehicleId: widget.vehicleId,
              data: {
                'name': updated['name'],
                'vehicle_type': updated['type'],
                'matricule': updated['matricule'],
                'status': updated['status'],
                'affectation': updated['affectation'],
                'parc_name': updated['parc'] ?? updated['parc_name'] ?? '',
                'parc': updated['parc'] ?? updated['parc_name'] ?? '',
                'insurance_start': updated['insuranceStart'],
                'insurance_expiry': updated['insuranceExpiry'],
                'inspection_expiry': updated['inspectionExpiry'],
                'oil_change_date': updated['oilChange'],
                'general_remark': updated['generalRemark'],
                'water_capacity': updated['water'],
                'emulsifier_capacity': updated['emulsifier'],
                'powder_capacity': updated['powder'],
                'cannon_range': updated['cannonRange'],
                'battery': updated['battery'],
                'wheel_ref': updated['wheelRef'],
              },
            );
            await _loadVehicle();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Informations mises à jour',
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

  void _confirmDeleteVehicle(BuildContext context, String vehicleName) {
    final vName = vehicleName.isNotEmpty ? vehicleName : (_displayData['name'] as String? ?? 'ce véhicule');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.criticalContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_forever,
                color: AppTheme.critical,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Supprimer le véhicule',
                style: GoogleFonts.ibmPlexSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppTheme.darkCharcoal,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment supprimer définitivement le véhicule "$vName" ?\n\nCette action est irréversible.',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            color: AppTheme.secondaryText,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Annuler',
              style: GoogleFonts.ibmPlexSans(color: AppTheme.mutedText),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _svc.deleteVehicle(widget.vehicleId);
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Véhicule "$vName" supprimé avec succès',
                              style: GoogleFonts.ibmPlexSans(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  } else {
                    context.go(AppRoutes.parkHomeScreen, extra: widget.role);
                  }
                }
              } catch (e) {
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur lors de la suppression: $e'),
                      backgroundColor: AppTheme.critical,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.critical,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Supprimer',
              style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMsg != null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppTheme.darkCharcoal,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomIconWidget(
                iconName: 'error_outline',
                color: AppTheme.critical,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Erreur de chargement',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMsg!,
                style: GoogleFonts.ibmPlexSans(color: AppTheme.mutedText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadVehicle,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final vehicle = _displayData;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(theme, innerBoxIsScrolled, vehicle),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tabs: const [
                  Tab(text: 'Informations'),
                  Tab(text: 'Agents extincteurs'),
                  Tab(text: 'Équipement'),
                  Tab(text: 'Maintenance'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            VehicleInfoTabWidget(vehicle: vehicle),
            FireAgentsTabWidget(vehicle: vehicle, canEdit: _canEdit),
            EquipmentTabWidget(
              vehicleId: widget.vehicleId,
              vehicleName: vehicle['name'] as String? ?? '',
              userRole: widget.role == 'Super Admin'
                  ? UserRole.superAdmin
                  : widget.role == 'Admin'
                  ? UserRole.admin
                  : UserRole.user,
            ),
            MaintenanceTabWidget(
              vehicleId: widget.vehicleId,
              vehicleName: vehicle['name'] as String? ?? '',
              userRole: widget.role == 'Super Admin'
                  ? UserRole.superAdmin
                  : widget.role == 'Admin'
                  ? UserRole.admin
                  : UserRole.user,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(
    ThemeData theme,
    bool innerBoxIsScrolled,
    Map<String, dynamic> vehicle,
  ) {
    final status = vehicle['status'] as String? ?? 'operational';

    return SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: 130,
      scrolledUnderElevation: 2,
      backgroundColor: _getStatusHeaderColor(status),
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          } else {
            if (widget.role == 'Super Admin') {
              context.go(AppRoutes.superAdminDashboardScreen);
            } else if (widget.role == 'Admin') {
              context.go(
                AppRoutes.adminDashboardScreen,
                extra: {'role': widget.role, 'username': 'admin'},
              );
            } else {
              context.go(AppRoutes.parkHomeScreen, extra: widget.role);
            }
          }
        },
        tooltip: 'Retour',
      ),
      actions: [
        if (_canEdit)
          IconButton(
            icon: CustomIconWidget(
              iconName: 'edit',
              color: Colors.white,
              size: 22,
            ),
            onPressed: _openEditSheet,
            tooltip: 'Modifier',
          ),
        IconButton(
          icon: const Icon(
            Icons.delete_outline,
            color: Colors.white,
            size: 22,
          ),
          onPressed: () => _confirmDeleteVehicle(context, vehicle['name'] as String? ?? ''),
          tooltip: 'Supprimer le véhicule',
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              vehicle['name'] as String? ?? '',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Row(
              children: [
                Text(
                  vehicle['matricule'] as String? ?? '',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusHeaderColor(String status) {
    switch (status) {
      case 'operational':
        return AppTheme.darkCharcoal;
      case 'maintenance':
        return AppTheme.warning;
      case 'out_of_service':
        return AppTheme.critical;
      default:
        return AppTheme.darkCharcoal;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (status) {
      case 'operational':
        label = 'Opérationnel';
        color = AppTheme.success;
        break;
      case 'maintenance':
        label = 'Maintenance';
        color = Colors.orange;
        break;
      case 'out_of_service':
        label = 'Hors service';
        color = AppTheme.critical;
        break;
      default:
        label = status;
        color = AppTheme.mutedText;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.ibmPlexSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppTheme.surfaceLight, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

// ── Edit Vehicle Sheet ────────────────────────────────────────────────────────
class _EditVehicleSheet extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  final Function(Map<String, dynamic>) onSave;
  const _EditVehicleSheet({required this.vehicle, required this.onSave});

  @override
  State<_EditVehicleSheet> createState() => _EditVehicleSheetState();
}

class _EditVehicleSheetState extends State<_EditVehicleSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _typeCtrl;
  late TextEditingController _matriculeCtrl;
  late TextEditingController _remarqueCtrl;
  late TextEditingController _waterCtrl;
  late TextEditingController _emulsifierCtrl;
  late TextEditingController _powderCtrl;
  late TextEditingController _cannonCtrl;
  late TextEditingController _batteryCtrl;
  late TextEditingController _wheelRefCtrl;
  late TextEditingController _affectationCtrl;
  late TextEditingController _parcCtrl;
  late String _selectedStatus;
  DateTime? _insuranceStart;
  DateTime? _insuranceExpiry;
  DateTime? _inspectionExpiry;
  DateTime? _oilChangeDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.vehicle['name'] as String? ?? '',
    );
    _typeCtrl = TextEditingController(
      text: widget.vehicle['type'] as String? ?? '',
    );
    _matriculeCtrl = TextEditingController(
      text: widget.vehicle['matricule'] as String? ?? '',
    );
    _remarqueCtrl = TextEditingController(
      text: widget.vehicle['generalRemark'] as String? ?? '',
    );
    _waterCtrl = TextEditingController(
      text: widget.vehicle['water'] as String? ?? '',
    );
    _emulsifierCtrl = TextEditingController(
      text: widget.vehicle['emulsifier'] as String? ?? '',
    );
    _powderCtrl = TextEditingController(
      text: widget.vehicle['powder'] as String? ?? '',
    );
    _cannonCtrl = TextEditingController(
      text: widget.vehicle['cannonRange'] as String? ?? '',
    );
    _batteryCtrl = TextEditingController(
      text: widget.vehicle['battery'] as String? ?? '',
    );
    _wheelRefCtrl = TextEditingController(
      text: widget.vehicle['wheelRef'] as String? ?? '',
    );
    _affectationCtrl = TextEditingController(
      text: widget.vehicle['affectation'] as String? ?? '',
    );
    _parcCtrl = TextEditingController(
      text: widget.vehicle['parc'] as String? ?? widget.vehicle['parc_name'] as String? ?? '',
    );
    _selectedStatus = widget.vehicle['status'] as String? ?? 'operational';

    final insStartStr = widget.vehicle['insuranceStart'] as String? ?? '';
    if (insStartStr.isNotEmpty) {
      try { _insuranceStart = DateTime.parse(insStartStr); } catch (_) {}
    }

    final insExpStr = widget.vehicle['insuranceExpiry'] as String? ?? '';
    if (insExpStr.isNotEmpty) {
      try { _insuranceExpiry = DateTime.parse(insExpStr); } catch (_) {}
    }

    final inspExpStr = widget.vehicle['inspectionExpiry'] as String? ?? '';
    if (inspExpStr.isNotEmpty) {
      try { _inspectionExpiry = DateTime.parse(inspExpStr); } catch (_) {}
    }

    final oilStr = widget.vehicle['oilChange'] as String? ?? '';
    if (oilStr.isNotEmpty) {
      try { _oilChangeDate = DateTime.parse(oilStr); } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _typeCtrl.dispose();
    _matriculeCtrl.dispose();
    _parcCtrl.dispose();
    _remarqueCtrl.dispose();
    _waterCtrl.dispose();
    _emulsifierCtrl.dispose();
    _powderCtrl.dispose();
    _cannonCtrl.dispose();
    _batteryCtrl.dispose();
    _wheelRefCtrl.dispose();
    _affectationCtrl.dispose();
    super.dispose();
  }

  Widget _buildDatePickerTile({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
    required IconData icon,
    required Color color,
  }) {
    final formatted = value == null
        ? 'Non définie'
        : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVariantLight),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: Icon(icon, color: color, size: 20),
        title: Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 11,
            color: AppTheme.mutedText,
          ),
        ),
        subtitle: Text(
          formatted,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: value == null ? AppTheme.mutedText : AppTheme.darkCharcoal,
          ),
        ),
        trailing: value != null
            ? GestureDetector(
                onTap: () => onChanged(null),
                child: const Icon(Icons.close, size: 18, color: AppTheme.mutedText),
              )
            : const Icon(Icons.calendar_month, size: 18, color: AppTheme.mutedText),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2015),
            lastDate: DateTime(2035),
          );
          if (picked != null) onChanged(picked);
        },
      ),
    );
  }

  String _formatIso(DateTime? d) {
    if (d == null) return '';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
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
                  'Modifier le véhicule',
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
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nom *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _typeCtrl,
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _matriculeCtrl,
              decoration: const InputDecoration(labelText: 'Matricule'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(labelText: 'Statut'),
              items: const [
                DropdownMenuItem(
                  value: 'operational',
                  child: Text('Opérationnel'),
                ),
                DropdownMenuItem(
                  value: 'maintenance',
                  child: Text('En maintenance'),
                ),
                DropdownMenuItem(
                  value: 'out_of_service',
                  child: Text('Hors service'),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _selectedStatus = v ?? 'operational'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _parcCtrl,
              decoration: const InputDecoration(
                labelText: 'Parc (Nom du parc)',
                hintText: 'ex: Parc RTH Sonatrach',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _affectationCtrl,
              decoration: const InputDecoration(
                labelText: 'Affectation (Emplacement du véhicule)',
                hintText: 'ex: Base RTH Hassi Messaoud, Zone A...',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Documents administratifs',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            _buildDatePickerTile(
              label: 'Début Assurance',
              value: _insuranceStart,
              onChanged: (v) => setState(() => _insuranceStart = v),
              icon: Icons.verified_user_outlined,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 8),
            _buildDatePickerTile(
              label: 'Échéance Assurance',
              value: _insuranceExpiry,
              onChanged: (v) => setState(() => _insuranceExpiry = v),
              icon: Icons.event_repeat,
              color: AppTheme.warning,
            ),
            const SizedBox(height: 8),
            _buildDatePickerTile(
              label: 'Échéance Contrôle Technique',
              value: _inspectionExpiry,
              onChanged: (v) => setState(() => _inspectionExpiry = v),
              icon: Icons.rule,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 8),
            _buildDatePickerTile(
              label: 'Date de Vidange',
              value: _oilChangeDate,
              onChanged: (v) => setState(() => _oilChangeDate = v),
              icon: Icons.oil_barrel_outlined,
              color: AppTheme.secondaryText,
            ),
            const SizedBox(height: 16),
            Text(
              'Spécifications techniques',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _batteryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Batterie',
                      hintText: 'ex: 12V 100Ah',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _wheelRefCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Réf. de roue',
                      hintText: 'ex: 315/80 R22.5',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _remarqueCtrl,
              decoration: const InputDecoration(labelText: 'Remarque générale'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        Navigator.pop(context);
                        await widget.onSave({
                          'name': _nameCtrl.text.trim(),
                          'type': _typeCtrl.text.trim(),
                          'matricule': _matriculeCtrl.text.trim(),
                          'status': _selectedStatus,
                          'parc': _parcCtrl.text.trim(),
                          'parc_name': _parcCtrl.text.trim(),
                          'affectation': _affectationCtrl.text.trim(),
                          'generalRemark': _remarqueCtrl.text.trim(),
                          'water': _waterCtrl.text.trim(),
                          'emulsifier': _emulsifierCtrl.text.trim(),
                          'powder': _powderCtrl.text.trim(),
                          'cannonRange': _cannonCtrl.text.trim(),
                          'battery': _batteryCtrl.text.trim(),
                          'wheelRef': _wheelRefCtrl.text.trim(),
                          'insuranceStart': _formatIso(_insuranceStart),
                          'insuranceExpiry': _formatIso(_insuranceExpiry),
                          'inspectionExpiry': _formatIso(_inspectionExpiry),
                          'oilChange': _formatIso(_oilChangeDate),
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
