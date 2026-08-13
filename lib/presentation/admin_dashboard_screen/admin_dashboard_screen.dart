import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_export.dart';
import '../../../services/supabase_service.dart';
import '../profile_screen/profile_screen.dart';
import './widgets/admin_alert_list_widget.dart';
import './widgets/admin_fleet_chart_widget.dart';
import './widgets/admin_kpi_grid_widget.dart';
import './widgets/admin_vehicle_status_list_widget.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String role;
  final String username;

  const AdminDashboardScreen({
    super.key,
    this.role = 'Admin',
    this.username = 'admin',
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
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

  bool get _isSuperAdmin => widget.role == 'Super Admin';

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _vehiclesChannel?.unsubscribe();
    _alertsChannel?.unsubscribe();
    _auditChannel?.unsubscribe();
    _nameCtrl.dispose();
    _typeCtrl.dispose();
    _matriculeCtrl.dispose();
    _remarqueCtrl.dispose();
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
      ]);

      if (mounted) {
        final stats = results[0] as Map<String, dynamic>;
        final alerts = results[1] as List<Map<String, dynamic>>;
        final vehicles = results[2] as List<Map<String, dynamic>>;
        final audit = results[3] as List<Map<String, dynamic>>;

        setState(() {
          _stats = stats;
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
                  'icon': _iconForAction(a['action'] as String? ?? ''),
                  'color': _colorForAction(a['action'] as String? ?? ''),
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
        .channel('admin_vehicles')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vehicles',
          callback: (_) => _loadData(),
        )
        .subscribe();

    _alertsChannel = _svc.client
        .channel('admin_alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'alerts',
          callback: (_) => _loadData(),
        )
        .subscribe();

    _auditChannel = _svc.client
        .channel('admin_audit')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'audit_logs',
          callback: (_) => _loadData(),
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

  String _iconForAction(String action) {
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

  Color _colorForAction(String action) {
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

  List<Map<String, dynamic>> get _kpiData {
    return [
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
  }

  // ── Add Vehicle Sheet controllers ─────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _matriculeCtrl = TextEditingController();
  String _selectedStatus = 'operational';
  DateTime? _insuranceDate;
  DateTime? _inspectionDate;
  DateTime? _serviceDate;
  final _remarqueCtrl = TextEditingController();

  void _showAddVehicleSheet() {
    _nameCtrl.clear();
    _typeCtrl.clear();
    _matriculeCtrl.clear();
    _remarqueCtrl.clear();
    _selectedStatus = 'operational';
    _insuranceDate = null;
    _inspectionDate = null;
    _serviceDate = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddVehicleBottomSheet(
        nameCtrl: _nameCtrl,
        typeCtrl: _typeCtrl,
        matriculeCtrl: _matriculeCtrl,
        remarqueCtrl: _remarqueCtrl,
        selectedStatus: _selectedStatus,
        onStatusChanged: (v) => setState(() => _selectedStatus = v),
        onSave: () async {
          if (_nameCtrl.text.trim().isEmpty) return;
          Navigator.pop(ctx);
          try {
            await _svc.createVehicle(
              name: _nameCtrl.text.trim(),
              vehicleType: _typeCtrl.text.trim(),
              matricule: _matriculeCtrl.text.trim(),
              status: _selectedStatus,
              insuranceExpiry: _insuranceDate
                  ?.toIso8601String()
                  .split('T')
                  .first,
              inspectionExpiry: _inspectionDate
                  ?.toIso8601String()
                  .split('T')
                  .first,
              oilChangeDate: _serviceDate?.toIso8601String().split('T').first,
              generalRemark: _remarqueCtrl.text.trim(),
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Véhicule ajouté avec succès',
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
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      drawer: _buildDrawer(theme),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(theme, innerBoxIsScrolled),
        ],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMsg != null
            ? _buildError()
            : RefreshIndicator(onRefresh: _loadData, child: _buildBody(theme)),
      ),
      floatingActionButton: _isSuperAdmin
          ? FloatingActionButton.extended(
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
            )
          : null,
    );
  }

  Widget _buildError() {
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
            'Erreur de chargement',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMsg ?? '',
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

  Widget _buildSliverAppBar(ThemeData theme, bool innerBoxIsScrolled) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: AppTheme.darkCharcoal,
      foregroundColor: Colors.white,
      expandedHeight: 100,
      scrolledUnderElevation: 2,
      elevation: 0,
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
      actions: [
        IconButton(
          icon: CustomIconWidget(
            iconName: 'refresh',
            color: Colors.white,
            size: 22,
          ),
          onPressed: _loadData,
          tooltip: 'Actualiser',
        ),
        IconButton(
          icon: CustomIconWidget(
            iconName: 'account_circle',
            color: Colors.white,
            size: 26,
          ),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 14),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tableau de bord',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              widget.username,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Grid
          AdminKpiGridWidget(kpiData: _kpiData, role: 'Admin'),
          const SizedBox(height: 20),

          // Fleet chart
          Text(
            'Répartition de la flotte',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkCharcoal,
            ),
          ),
          const SizedBox(height: 10),
          AdminFleetChartWidget(
            operational: (_stats['operational'] as int?) ?? 0,
            maintenance: (_stats['maintenance'] as int?) ?? 0,
            outOfService: (_stats['outOfService'] as int?) ?? 0,
          ),
          const SizedBox(height: 20),

          // Alerts
          if (_alertData.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  'Alertes actives',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkCharcoal,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push(
                    AppRoutes.alertsScreen,
                    extra: {'role': widget.role},
                  ),
                  child: Text(
                    'Voir tout',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AdminAlertListWidget(alerts: _alertData),
            const SizedBox(height: 20),
          ],

          // Vehicle status
          Text(
            'Statut des véhicules',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkCharcoal,
            ),
          ),
          const SizedBox(height: 10),
          AdminVehicleStatusListWidget(
            vehicles: _vehicleStatusData,
            onVehicleTap: (vehicleId) {
              context.push(
                AppRoutes.vehicleDetailsScreen,
                extra: {
                  'vehicleId': vehicleId,
                  'role': widget.role,
                },
              );
            },
          ),
          const SizedBox(height: 20),

          // Audit log (Journal d'activité) — Super Admin only
          if (_isSuperAdmin && _auditLog.isNotEmpty) ...[
            Text(
              'Journal d\'activité',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkCharcoal,
              ),
            ),
            const SizedBox(height: 10),
            _buildAuditLog(),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildAuditLog() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariantLight),
      ),
      child: Column(
        children: _auditLog.asMap().entries.map((entry) {
          final i = entry.key;
          final log = entry.value;
          final isLast = i == _auditLog.length - 1;
          final color = log['color'] as Color? ?? AppTheme.primary;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: CustomIconWidget(
                          iconName: log['icon'] as String? ?? 'info',
                          color: color,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log['action'] as String? ?? '',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.darkCharcoal,
                            ),
                          ),
                          Text(
                            '${log['user']} • ${log['time']}',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 11,
                              color: AppTheme.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) const Divider(height: 1, indent: 14, endIndent: 14),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDrawer(ThemeData theme) {
    final drawerItems = [
      {'icon': 'dashboard', 'label': 'Tableau de bord', 'route': ''},
      {
        'icon': 'local_fire_department',
        'label': 'Parc véhicules',
        'route': AppRoutes.parkHomeScreen,
      },
      {
        'icon': 'notifications_active',
        'label': 'Alertes',
        'route': AppRoutes.alertsScreen,
      },
      {
        'icon': 'inventory_2',
        'label': 'Définitions équipements',
        'route': AppRoutes.equipmentDefinitionsScreen,
      },
      if (_isSuperAdmin)
        {
          'icon': 'people',
          'label': 'Utilisateurs',
          'route': AppRoutes.userManagementScreen,
        },
    ];

    return Drawer(
      backgroundColor: AppTheme.surfaceLight,
      child: Column(
        children: [
          // Premium Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E272C), Color(0xFF2C3E50)],
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
                          'Gestion du Parc',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 11,
                            color: Colors.white.withAlpha(150),
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
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            widget.username.isNotEmpty
                                ? widget.username[0].toUpperCase()
                                : 'A',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.username,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.role,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 10,
                                color: Colors.white.withAlpha(180),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Drawer Navigation Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: drawerItems.length,
              itemBuilder: (ctx, i) {
                final item = drawerItems[i];
                final isSelected = _drawerIndex == i;
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withAlpha(20)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    leading: CustomIconWidget(
                      iconName: item['icon']!,
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.secondaryText,
                      size: 22,
                    ),
                    title: Text(
                      item['label']!,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.darkCharcoal,
                      ),
                    ),
                    onTap: () {
                      setState(() => _drawerIndex = i);
                      Navigator.pop(ctx);
                      final route = item['route']!;
                      if (route.isNotEmpty) {
                        if (route == AppRoutes.alertsScreen) {
                          context.push(route, extra: {'role': widget.role});
                        } else if (route == AppRoutes.parkHomeScreen) {
                          context.push(route, extra: widget.role);
                        } else {
                          context.push(route);
                        }
                      }
                    },
                  ),
                );
              },
            ),
          ),

          // Drawer Footer
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
                    iconName: 'code',
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  title: Text(
                    'Développé par Haitham BADEREDDINE',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
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
                  onTap: () async {
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
              await _svc.signOut();
              if (mounted) context.go(AppRoutes.adminLoginScreen);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.critical,
              foregroundColor: Colors.white,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }
}

// ── Add Vehicle Bottom Sheet ──────────────────────────────────────────────────
class _AddVehicleBottomSheet extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController typeCtrl;
  final TextEditingController matriculeCtrl;
  final TextEditingController remarqueCtrl;
  final String selectedStatus;
  final Function(String) onStatusChanged;
  final VoidCallback onSave;

  const _AddVehicleBottomSheet({
    required this.nameCtrl,
    required this.typeCtrl,
    required this.matriculeCtrl,
    required this.remarqueCtrl,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.onSave,
  });

  @override
  State<_AddVehicleBottomSheet> createState() => _AddVehicleBottomSheetState();
}

class _AddVehicleBottomSheetState extends State<_AddVehicleBottomSheet> {
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.selectedStatus;
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
                  'Nouveau véhicule',
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
              controller: widget.nameCtrl,
              decoration: const InputDecoration(labelText: 'Nom du véhicule *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.typeCtrl,
              decoration: const InputDecoration(
                labelText: 'Type (VMR 80, VMR 115...)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.matriculeCtrl,
              decoration: const InputDecoration(labelText: 'Matricule'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
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
              onChanged: (v) {
                setState(() => _status = v ?? 'operational');
                widget.onStatusChanged(_status);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.remarqueCtrl,
              decoration: const InputDecoration(labelText: 'Remarque'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onSave,
                child: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
