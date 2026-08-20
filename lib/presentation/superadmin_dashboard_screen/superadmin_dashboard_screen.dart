import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';
import '../../services/presence_service.dart';
import '../../services/supabase_service.dart';
import '../admin_dashboard_screen/widgets/admin_alert_list_widget.dart';
import '../admin_dashboard_screen/widgets/admin_fleet_chart_widget.dart';
import '../admin_dashboard_screen/widgets/admin_kpi_grid_widget.dart';
import '../admin_dashboard_screen/widgets/admin_vehicle_status_list_widget.dart';
import '../profile_screen/profile_screen.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  final String username;

  const SuperAdminDashboardScreen({super.key, this.username = 'superadmin'});

  @override
  State<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  int _drawerIndex = 0;
  final _svc = SupabaseService.instance;

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _alertData = [];
  List<Map<String, dynamic>> _vehicleStatusData = [];
  List<Map<String, dynamic>> _auditLog = [];
  bool _isLoading = true;
  String? _errorMsg;

  RealtimeChannel? _vehiclesChannel;
  RealtimeChannel? _alertsChannel;
  RealtimeChannel? _auditChannel;

  List<Map<String, dynamic>> get _kpiData => [
    {
      'label': 'Total véhicules',
      'value': '${_stats['total'] ?? 0}',
      'icon': 'fire_truck',
      'color': AppTheme.darkCharcoal,
      'bgColor': AppTheme.surfaceVariantLight,
      'trend': '+0',
    },
    {
      'label': 'Opérationnels',
      'value': '${_stats['operational'] ?? 0}',
      'icon': 'check_circle',
      'color': AppTheme.success,
      'bgColor': AppTheme.successContainer,
      'trend': '+0',
    },
    {
      'label': 'En maintenance',
      'value': '${_stats['maintenance'] ?? 0}',
      'icon': 'build',
      'color': AppTheme.warning,
      'bgColor': AppTheme.warningContainer,
      'trend': '+0',
    },
    {
      'label': 'Hors service',
      'value': '${_stats['outOfService'] ?? 0}',
      'icon': 'cancel',
      'color': AppTheme.critical,
      'bgColor': AppTheme.criticalContainer,
      'trend': '0',
    },
    {
      'label': 'Alertes équip.',
      'value': '${_stats['totalMissing'] ?? 0}',
      'icon': 'inventory_2',
      'color': AppTheme.warning,
      'bgColor': AppTheme.warningContainer,
      'trend': '+0',
    },
    {
      'label': 'Docs expirés',
      'value': '${_stats['expiredDocs'] ?? 0}',
      'icon': 'description',
      'color': AppTheme.critical,
      'bgColor': AppTheme.criticalContainer,
      'trend': '+0',
    },
  ];

  int _activePresencesCount = 1;
  RealtimeChannel? _presenceChannel;

  // System stats for Super Admin — computed from live _stats data
  List<Map<String, dynamic>> get _systemStats => [
    {
      'label': 'Connectés (Actifs)',
      'value': '$_activePresencesCount',
      'icon': 'sensors',
      'color': AppTheme.success,
    },
    {
      'label': 'Utilisateurs',
      'value': '${_stats['usersCount'] ?? 0}',
      'icon': 'people',
      'color': AppTheme.primary,
    },
    {
      'label': 'Parcs gérés',
      'value': '${_stats['parksCount'] ?? 0}',
      'icon': 'local_fire_department',
      'color': AppTheme.warning,
    },
    {
      'label': 'Alertes actives',
      'value': '${_stats['totalAlerts'] ?? 0}',
      'icon': 'notifications_active',
      'color': AppTheme.critical,
    },
  ];

  // Add Vehicle Sheet controllers
  final _nameCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _matriculeCtrl = TextEditingController();
  String _selectedStatus = 'operational';
  final _remarqueCtrl = TextEditingController();
  final _batteryCtrl = TextEditingController();
  final _wheelRefCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    PresenceService.instance.startPresence(role: 'Super Admin', userName: 'Super Admin');
    _loadData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _vehiclesChannel?.unsubscribe();
    _alertsChannel?.unsubscribe();
    _auditChannel?.unsubscribe();
    _presenceChannel?.unsubscribe();
    _nameCtrl.dispose();
    _typeCtrl.dispose();
    _matriculeCtrl.dispose();
    _remarqueCtrl.dispose();
    _batteryCtrl.dispose();
    _wheelRefCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final results = await Future.wait([
        _svc.getDashboardStats(),
        _svc.getAlerts(dismissed: false),
        _svc.getVehicles(),
        _svc.getAuditLogs(limit: 10),
        _svc.getActivePresencesCount(),
      ]);

      if (mounted) {
        final stats = results[0] as Map<String, dynamic>;
        final alerts = results[1] as List<Map<String, dynamic>>;
        final vehicles = results[2] as List<Map<String, dynamic>>;
        final audit = results[3] as List<Map<String, dynamic>>;
        final activeCount = results[4] as int;

        // Fetch user counts (non-blocking — Edge Function may fail)
        int adminsCount = 0;
        int usersCount = 0;
        try {
          final users = await _svc.listUsers();
          usersCount = users.length;
          adminsCount = users.where((u) {
            final role = (u['role'] as String?) ??
                (u['user_metadata'] is Map
                    ? (u['user_metadata']['role'] as String?) ?? ''
                    : '');
            final r = role.toLowerCase();
            return r == 'admin' || r == 'super admin' || r == 'super_admin' || r == 'superadmin';
          }).length;
        } catch (_) {
          // Edge Function unavailable — leave at 0
        }

        setState(() {
          _activePresencesCount = activeCount;
          _stats = {
            ...stats,
            'adminsCount': adminsCount,
            'usersCount': usersCount,
          };
          _alertData = alerts
              .take(6)
              .map(
                (a) => {
                  'type': a['severity'] == 'critical'
                      ? 'critical'
                      : a['severity'] == 'warning'
                      ? 'warning'
                      : 'info',
                  'icon': _iconForCategory(a['category'] as String? ?? ''),
                  'message': a['title'] as String? ?? '',
                  'vehicle': a['vehicle_name'] as String? ?? '',
                  'action': 'Voir',
                },
              )
              .toList();

          _vehicleStatusData = vehicles
              .map(
                (v) => {
                  'name': v['name'] ?? '',
                  'matricule': v['matricule'] ?? '',
                  'status': v['status'] ?? 'operational',
                  'insurance': _docStatus(v['insurance_expiry'] as String?),
                  'inspection': _docStatus(v['inspection_expiry'] as String?),
                  'missing': v['missing_equipment_count'] ?? 0,
                  'id': v['id'] ?? '',
                },
              )
              .toList();

          _auditLog = audit
              .map(
                (a) => {
                  'user': a['username'] ?? '',
                  'action': a['description'] ?? '',
                  'time': _formatTime(a['created_at'] as String?),
                  'icon': _iconForAuditAction(a['action'] as String? ?? ''),
                  'color': _colorForAuditAction(a['action'] as String? ?? ''),
                },
              )
              .toList();

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
    _vehiclesChannel = _svc.client
        .channel('superadmin_vehicles')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vehicles',
          callback: (_) => _loadData(),
        )
        .subscribe();

    _alertsChannel = _svc.client
        .channel('superadmin_alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'alerts',
          callback: (_) => _loadData(),
        )
        .subscribe();

    _auditChannel = _svc.client
        .channel('superadmin_audit')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'audit_logs',
          callback: (_) => _loadData(),
        )
        .subscribe();

    _presenceChannel = _svc.client
        .channel('superadmin_presences')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_presences',
          callback: (_) async {
            final activeCount = await _svc.getActivePresencesCount();
            if (mounted) {
              setState(() {
                _activePresencesCount = activeCount;
              });
            }
          },
        )
        .subscribe();
  }

  String _docStatus(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'valid';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = date.difference(now).inDays;
      if (diff < 0) return 'expired';
      if (diff < 30) return 'expiring';
      return 'valid';
    } catch (_) {
      return 'valid';
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        return 'Aujourd\'hui ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      if (diff.inDays == 1) {
        return 'Hier ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  String _iconForCategory(String cat) {
    switch (cat) {
      case 'insurance':
        return 'description';
      case 'inspection':
        return 'fact_check';
      case 'equipment':
        return 'inventory_2';
      case 'maintenance':
        return 'build';
      default:
        return 'warning';
    }
  }

  String _iconForAuditAction(String action) {
    switch (action) {
      case 'vehicle_created':
        return 'add_circle';
      case 'vehicle_updated':
        return 'edit';
      case 'maintenance_added':
        return 'build';
      case 'equipment_updated':
        return 'inventory_2';
      case 'user_created':
        return 'person_add';
      case 'user_disabled':
        return 'person_off';
      case 'user_enabled':
        return 'person';
      default:
        return 'info';
    }
  }

  Color _colorForAuditAction(String action) {
    switch (action) {
      case 'vehicle_created':
        return AppTheme.success;
      case 'vehicle_updated':
        return AppTheme.primary;
      case 'maintenance_added':
        return AppTheme.warning;
      case 'equipment_updated':
        return AppTheme.warning;
      case 'user_created':
        return AppTheme.success;
      case 'user_disabled':
        return AppTheme.critical;
      default:
        return AppTheme.primary;
    }
  }



  void _showAddVehicleSheet() {
    _nameCtrl.clear();
    _typeCtrl.clear();
    _matriculeCtrl.clear();
    _remarqueCtrl.clear();
    _batteryCtrl.clear();
    _wheelRefCtrl.clear();
    _selectedStatus = 'operational';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildAddVehicleSheet(ctx),
    );
  }

  Widget _buildLoadingOrError() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Center(
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
            'Erreur: $_errorMsg',
            style: GoogleFonts.ibmPlexSans(color: AppTheme.mutedText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddVehicleSheet(BuildContext ctx) {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Ajouter un véhicule',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkCharcoal,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: CustomIconWidget(
                        iconName: 'close',
                        color: AppTheme.secondaryText,
                        size: 22,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSheetField(
                  'Nom du véhicule',
                  _nameCtrl,
                  'ex: VMR 80 N°3',
                ),
                const SizedBox(height: 12),
                _buildSheetField('Type', _typeCtrl, 'ex: VMR 80'),
                const SizedBox(height: 12),
                _buildSheetField(
                  'Matricule',
                  _matriculeCtrl,
                  'ex: 00664-209-31',
                ),
                const SizedBox(height: 12),
                _buildSheetField(
                  'Batterie',
                  _batteryCtrl,
                  'ex: 12V 100Ah',
                ),
                const SizedBox(height: 12),
                _buildSheetField(
                  'Réf. de roue',
                  _wheelRefCtrl,
                  'ex: 315/80 R22.5',
                ),
                const SizedBox(height: 12),
                Text(
                  'Statut',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkCharcoal,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppTheme.outlineVariantLight,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
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
                      setSheetState(() => _selectedStatus = v ?? 'operational'),
                ),
                const SizedBox(height: 12),
                _buildSheetField(
                  'Remarques',
                  _remarqueCtrl,
                  'Optionnel',
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_nameCtrl.text.trim().isEmpty) return;
                      Navigator.pop(context);
                      try {
                        await _svc.createVehicle(
                          name: _nameCtrl.text.trim(),
                          vehicleType: _typeCtrl.text.trim(),
                          matricule: _matriculeCtrl.text.trim(),
                          status: _selectedStatus,
                          generalRemark: _remarqueCtrl.text.trim(),
                          battery: _batteryCtrl.text.trim(),
                          wheelRef: _wheelRefCtrl.text.trim(),
                        );
                        await _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Véhicule "${_nameCtrl.text}" ajouté avec succès',
                                style: GoogleFonts.ibmPlexSans(
                                  color: Colors.white,
                                ),
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
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur: $e'),
                              backgroundColor: AppTheme.critical,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Enregistrer',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetField(
    String label,
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkCharcoal,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              color: AppTheme.mutedText,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.outlineVariantLight),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        drawer: _buildDrawer(context),
        body: CustomScrollView(
          slivers: [
            _buildSliverAppBar(theme),
            SliverToBoxAdapter(
              child: _isLoading || _errorMsg != null
                  ? SizedBox(height: 400, child: _buildLoadingOrError())
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildSuperAdminContent(),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddVehicleSheet,
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          icon: CustomIconWidget(
            iconName: 'add',
            color: Colors.white,
            size: 22,
          ),
          label: Text(
            'Ajouter véhicule',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Super Admin full content ─────────────────────────────────────────────
  Widget _buildSuperAdminContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGreeting(),
        const SizedBox(height: 20),
        _buildSuperAdminBanner(),
        const SizedBox(height: 20),

        // System stats row (Super Admin exclusive)
        _buildSectionLabel('Statistiques système'),
        const SizedBox(height: 10),
        _buildSystemStats(),
        const SizedBox(height: 20),

        // KPI Grid
        _buildSectionLabel('Vue d\'ensemble du parc'),
        const SizedBox(height: 10),
        AdminKpiGridWidget(kpiData: _kpiData, role: 'Super Admin'),
        const SizedBox(height: 20),

        // Fleet status chart
        _buildSectionLabel('Statut opérationnel — 30 derniers jours'),
        const SizedBox(height: 10),
        AdminFleetChartWidget(
          operational: (_stats['operational'] as int?) ?? 0,
          maintenance: (_stats['maintenance'] as int?) ?? 0,
          outOfService: (_stats['outOfService'] as int?) ?? 0,
        ),
        const SizedBox(height: 20),

        // Alerts
        _buildSectionLabel(
          'Alertes actives',
          badge: _alertData
              .where((a) => a['type'] == 'critical')
              .length
              .toString(),
          badgeColor: AppTheme.critical,
        ),
        const SizedBox(height: 10),
        AdminAlertListWidget(alerts: _alertData),
        const SizedBox(height: 20),

        // Vehicle status
        _buildSectionLabel('État des véhicules'),
        const SizedBox(height: 10),
        AdminVehicleStatusListWidget(
          vehicles: _vehicleStatusData,
          onVehicleTap: (id) => context.push(
            AppRoutes.vehicleDetailsScreen,
            extra: {'vehicleId': id, 'role': 'Super Admin'},
          ),
        ),
        const SizedBox(height: 20),

        // Audit log
        _buildSectionLabel('Journal d\'activité récent'),
        const SizedBox(height: 10),
        _buildAuditLog(),
        const SizedBox(height: 20),

        // Super Admin quick actions
        _buildSectionLabel('Actions Super Admin'),
        const SizedBox(height: 10),
        _buildSuperAdminQuickActions(),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─── System stats (Super Admin exclusive) ────────────────────────────────
  Widget _buildSystemStats() {
    return Row(
      children: _systemStats.map((stat) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: _systemStats.last == stat ? 0 : 8),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: (stat['color'] as Color).withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (stat['color'] as Color).withAlpha(50)),
            ),
            child: Column(
              children: [
                CustomIconWidget(
                  iconName: stat['icon'] as String,
                  color: stat['color'] as Color,
                  size: 20,
                ),
                const SizedBox(height: 6),
                Text(
                  stat['value'] as String,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkCharcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stat['label'] as String,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 9,
                    color: AppTheme.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Super Admin banner ───────────────────────────────────────────────────
  Widget _buildSuperAdminBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A237E).withAlpha(230),
            const Color(0xFF283593),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomIconWidget(
              iconName: 'admin_panel_settings',
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accès Super Administrateur',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Contrôle total — gestion des utilisateurs, parcs, configuration',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    color: Colors.white.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withAlpha(60)),
            ),
            child: Text(
              'FULL ACCESS',
              style: GoogleFonts.ibmPlexMono(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Audit log ────────────────────────────────────────────────────────────
  Widget _buildAuditLog() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariantLight),
      ),
      child: Column(
        children: [
          ..._auditLog.map((entry) {
            final isLast = _auditLog.last == entry;
            return Column(
              children: [
                ListTile(
                  dense: true,
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: (entry['color'] as Color).withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: CustomIconWidget(
                        iconName: entry['icon'] as String,
                        color: entry['color'] as Color,
                        size: 18,
                      ),
                    ),
                  ),
                  title: Text(
                    entry['action'] as String,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.darkCharcoal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${entry['user']}  ·  ${entry['time']}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      color: AppTheme.mutedText,
                    ),
                  ),
                ),
                if (!isLast)
                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppTheme.outlineVariantLight,
                  ),
              ],
            );
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: TextButton.icon(
              onPressed: () => _showComingSoon('Journal d\'activité complet'),
              icon: CustomIconWidget(
                iconName: 'history',
                color: AppTheme.primary,
                size: 16,
              ),
              label: Text(
                'Voir tout le journal',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Super Admin quick actions ────────────────────────────────────────────
  Widget _buildSuperAdminQuickActions() {
    final actions = [
      {
        'icon': 'people',
        'label': 'Gérer les\nutilisateurs',
        'color': const Color(0xFF1A237E),
        'onTap': () => context.push(AppRoutes.userManagementScreen),
      },
      {
        'icon': 'local_fire_department',
        'label': 'Gérer les\nparcs',
        'color': AppTheme.primary,
        'onTap': () =>
            context.push(AppRoutes.parkHomeScreen, extra: 'Super Admin'),
      },
      {
        'icon': 'inventory_2',
        'label': 'Définitions\néquipements',
        'color': AppTheme.warning,
        'onTap': () => context.push(AppRoutes.equipmentDefinitionsScreen),
      },
      {
        'icon': 'settings',
        'label': 'Configuration\nsystème',
        'color': AppTheme.secondaryText,
        'onTap': () => _showComingSoon('Configuration'),
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.4,
      children: actions.map((action) {
        return InkWell(
          onTap: action['onTap'] as VoidCallback,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: (action['color'] as Color).withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (action['color'] as Color).withAlpha(60),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: (action['color'] as Color).withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CustomIconWidget(
                    iconName: action['icon'] as String,
                    color: action['color'] as Color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    action['label'] as String,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkCharcoal,
                      height: 1.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature — fonctionnalité à venir',
          style: GoogleFonts.ibmPlexSans(color: Colors.white),
        ),
        backgroundColor: AppTheme.darkCharcoal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildSliverAppBar(ThemeData theme) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: const Color(0xFF1A237E),
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 2,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: CustomIconWidget(
            iconName: 'menu',
            color: Colors.white,
            size: 24,
          ),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
            ),
            padding: const EdgeInsets.all(3),
            child: CustomImageWidget(
              imageUrl: 'assets/images/logo-1786569551645.jpeg',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              semanticLabel: 'Logo Sonatrach',
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'TRC RTH',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white.withAlpha(60)),
            ),
            child: Text(
              'SUPER ADMIN',
              style: GoogleFonts.ibmPlexMono(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: CustomIconWidget(
            iconName: 'account_circle',
            color: Colors.white,
            size: 26,
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  ProfileScreen(role: 'Super Admin', username: widget.username),
            ),
          ),
          tooltip: 'Profil',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildGreeting() {
    final now = DateTime.now();
    final dateStr =
        '${now.day} août ${now.year}, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour, ${widget.username}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A237E).withAlpha(100),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: const Color(0xFF5C6BC0).withAlpha(150),
                        ),
                      ),
                      child: Text(
                        'SUPER ADMIN',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF9FA8DA),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Parc RTH — Hassi Messaoud',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        color: Colors.white.withAlpha(140),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  dateStr,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 11,
                    color: Colors.white.withAlpha(102),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: CustomIconWidget(
                iconName: 'shield',
                color: const Color(0xFF9FA8DA),
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, {String? badge, Color? badgeColor}) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkCharcoal,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (badgeColor ?? AppTheme.primary).withAlpha(31),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: badgeColor ?? AppTheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final drawerItems = [
      {'icon': 'dashboard', 'label': 'Tableau de bord', 'index': 0},
      {'icon': 'fire_truck', 'label': 'Véhicules', 'index': 1},
      {'icon': 'build', 'label': 'Maintenance', 'index': 3},
      {'icon': 'notifications_active', 'label': 'Alertes', 'index': 4},
      {'icon': 'people', 'label': 'Utilisateurs', 'index': 5},
      {'icon': 'local_fire_department', 'label': 'Parcs', 'index': 6},
      {'icon': 'history', 'label': 'Journal d\'activité', 'index': 7},
      {'icon': 'settings', 'label': 'Configuration', 'index': 8},
    ];

    return Drawer(
      backgroundColor: AppTheme.surfaceLight,
      child: Column(
        children: [
          // Drawer header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A237E), Color(0xFF283593)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(5),
                      child: CustomImageWidget(
                        imageUrl: 'assets/images/logo-1786569551645.jpeg',
                        width: 34,
                        height: 34,
                        fit: BoxFit.contain,
                        semanticLabel: 'Logo Sonatrach',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TRC RTH',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'Super Administration',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 11,
                            color: Colors.white.withAlpha(140),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withAlpha(38)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A237E).withAlpha(100),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            widget.username[0].toUpperCase(),
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF9FA8DA),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.username,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Super Admin',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 10,
                              color: const Color(0xFF9FA8DA),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: drawerItems.map((item) {
                final isSelected = _drawerIndex == item['index'] as int;
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1A237E).withAlpha(20)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: CustomIconWidget(
                      iconName: item['icon'] as String,
                      color: isSelected
                          ? const Color(0xFF1A237E)
                          : AppTheme.secondaryText,
                      size: 22,
                    ),
                    title: Text(
                      item['label'] as String,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? const Color(0xFF1A237E)
                            : AppTheme.darkCharcoal,
                      ),
                    ),
                    onTap: () {
                      setState(() => _drawerIndex = item['index'] as int);
                      Navigator.pop(context);
                      final idx = item['index'] as int;
                      if (idx == 1) {
                        context.push(
                          AppRoutes.parkHomeScreen,
                          extra: 'Super Admin',
                        );
                      } else if (idx == 2) {
                        context.push(AppRoutes.equipmentDefinitionsScreen);
                      } else if (idx == 3) {
                        // Navigate to fleet view — tap any vehicle to see its Maintenance tab
                        context.push(
                          AppRoutes.parkHomeScreen,
                          extra: 'Super Admin',
                        );
                      } else if (idx == 4) {
                        context.push(
                          AppRoutes.alertsScreen,
                          extra: {'role': 'Super Admin'},
                        );
                      } else if (idx == 5) {
                        context.push(AppRoutes.userManagementScreen);
                      } else if (idx == 6) {
                        context.push(
                          AppRoutes.parkHomeScreen,
                          extra: 'Super Admin',
                        );
                      } else if (idx == 7) {
                        _showComingSoon('Journal d\'activité');
                      } else if (idx == 8) {
                        _showComingSoon('Configuration');
                      }
                    },
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Drawer footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppTheme.outlineVariantLight, width: 1),
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: CustomIconWidget(
                    iconName: 'qr_code_scanner',
                    color: AppTheme.secondaryText,
                    size: 22,
                  ),
                  title: Text(
                    'Scanner QR Parc',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      color: AppTheme.darkCharcoal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.go(AppRoutes.qrScannerScreen);
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  leading: CustomIconWidget(
                    iconName: 'logout',
                    color: AppTheme.critical,
                    size: 22,
                  ),
                  title: Text(
                    'Déconnexion',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      color: AppTheme.critical,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog();
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Déconnexion',
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.w700,
            color: AppTheme.darkCharcoal,
          ),
        ),
        content: Text(
          'Voulez-vous vraiment vous déconnecter ?',
          style: GoogleFonts.ibmPlexSans(color: AppTheme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Annuler',
              style: GoogleFonts.ibmPlexSans(color: AppTheme.secondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await SupabaseService.instance.signOut();
              } catch (_) {}
              await Future.microtask(() {});
              if (mounted && context.mounted) {
                context.go(AppRoutes.adminLoginScreen);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.critical,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Déconnexion',
              style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
