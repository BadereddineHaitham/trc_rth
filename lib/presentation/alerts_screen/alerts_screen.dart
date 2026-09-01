import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------
enum AlertCategory { insurance, inspection, maintenance, equipment }

enum AlertSeverity { ok, warning, critical }

class AlertItem {
  final String id;
  final AlertCategory category;
  final AlertSeverity severity;
  final String title;
  final String subtitle;
  final String vehicleName;
  final String? detail;
  bool resolved;
  String? resolvedBy;
  DateTime? resolvedAt;

  AlertItem({
    required this.id,
    required this.category,
    required this.severity,
    required this.title,
    required this.subtitle,
    required this.vehicleName,
    this.detail,
    this.resolved = false,
    this.resolvedBy,
    this.resolvedAt,
  });

  factory AlertItem.fromMap(Map<String, dynamic> m) {
    DateTime? resolvedAt;
    final dismissedAt = m['dismissed_at'] as String?;
    if (dismissedAt != null && dismissedAt.isNotEmpty) {
      resolvedAt = DateTime.tryParse(dismissedAt);
    }

    return AlertItem(
      id: m['id'] as String? ?? '',
      category: _parseCategory(m['category'] as String? ?? ''),
      severity: _parseSeverity(m['severity'] as String? ?? ''),
      title: m['title'] as String? ?? '',
      subtitle: m['subtitle'] as String? ?? '',
      vehicleName: m['vehicle_name'] as String? ?? '',
      detail: m['detail'] as String?,
      resolved: m['dismissed'] as bool? ?? false,
      resolvedAt: resolvedAt,
    );
  }

  static AlertCategory _parseCategory(String s) {
    switch (s) {
      case 'insurance':
        return AlertCategory.insurance;
      case 'inspection':
        return AlertCategory.inspection;
      case 'maintenance':
        return AlertCategory.maintenance;
      case 'equipment':
        return AlertCategory.equipment;
      default:
        return AlertCategory.maintenance;
    }
  }

  static AlertSeverity _parseSeverity(String s) {
    switch (s) {
      case 'critical':
        return AlertSeverity.critical;
      case 'warning':
        return AlertSeverity.warning;
      default:
        return AlertSeverity.ok;
    }
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class AlertsScreen extends StatefulWidget {
  final String role;

  const AlertsScreen({super.key, this.role = 'User'});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showResolved = false;
  final _svc = SupabaseService.instance;

  List<AlertItem> _alerts = [];
  bool _isLoading = true;
  String? _errorMsg;
  RealtimeChannel? _channel;

  bool get _isSuperAdmin => widget.role == 'Super Admin';
  bool get _canManageAlerts => widget.role == 'Super Admin' || widget.role == 'Admin';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAlerts();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadAlerts({bool showLoading = false}) async {
    if (showLoading || _alerts.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMsg = null;
      });
    }
    try {
      final data = await _svc.getAlerts();
      if (mounted) {
        setState(() {
          _alerts = data.map((m) => AlertItem.fromMap(m)).toList();
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
        .channel('alerts_management_screen')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'alerts',
          callback: (_) => _loadAlerts(),
        )
        .subscribe();
  }

  List<AlertItem> _getFiltered(AlertCategory? category) {
    return _alerts.where((a) {
      if (category != null && a.category != category) return false;
      if (!_showResolved && a.resolved) return false;
      if (_showResolved && !a.resolved) return false;
      return true;
    }).toList()..sort((a, b) {
      final sOrder = {
        AlertSeverity.critical: 0,
        AlertSeverity.warning: 1,
        AlertSeverity.ok: 2,
      };
      return (sOrder[a.severity] ?? 2).compareTo(sOrder[b.severity] ?? 2);
    });
  }

  int get _activeCount => _alerts.where((a) => !a.resolved).length;
  int get _criticalCount => _alerts
      .where((a) => !a.resolved && a.severity == AlertSeverity.critical)
      .length;
  int get _resolvedCount => _alerts.where((a) => a.resolved).length;

  Future<void> _resolveAlert(AlertItem item) async {
    if (!_canManageAlerts) return;
    try {
      await _svc.dismissAlert(item.id);
      setState(() {
        item.resolved = true;
        item.resolvedAt = DateTime.now();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Alerte marquée comme résolue',
                  style: GoogleFonts.ibmPlexSans(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
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

  Future<void> _reopenAlert(AlertItem item) async {
    if (!_canManageAlerts) return;
    try {
      await _svc.restoreAlert(item.id);
      setState(() {
        item.resolved = false;
        item.resolvedAt = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Alerte réactivée',
              style: GoogleFonts.ibmPlexSans(color: Colors.white),
            ),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            floating: false,
            backgroundColor: AppTheme.darkCharcoal,
            foregroundColor: Colors.white,
            scrolledUnderElevation: 2,
            elevation: 0,
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
                  if (_isSuperAdmin) {
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
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Gestion des alertes',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (_criticalCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.critical,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_criticalCount',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              IconButton(
                icon: CustomIconWidget(
                  iconName: 'refresh',
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: _loadAlerts,
                tooltip: 'Actualiser',
              ),
              // Live indicator
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF69F0AE),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: CustomIconWidget(
                  iconName: _showResolved ? 'visibility_off' : 'visibility',
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: () => setState(() => _showResolved = !_showResolved),
                tooltip: _showResolved ? 'Voir actives' : 'Voir résolues',
              ),
              const SizedBox(width: 4),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(text: 'Toutes'),
                Tab(text: 'Assurance'),
                Tab(text: 'Contrôle tech.'),
                Tab(text: 'Maintenance'),
                Tab(text: 'Équipement'),
              ],
            ),
          ),
        ],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMsg != null
            ? _buildError()
            : Column(
                children: [
                  // Stats strip
                  if (!_showResolved) _buildStatsStrip(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAlertList(_getFiltered(null)),
                        _buildAlertList(_getFiltered(AlertCategory.insurance)),
                        _buildAlertList(_getFiltered(AlertCategory.inspection)),
                        _buildAlertList(
                          _getFiltered(AlertCategory.maintenance),
                        ),
                        _buildAlertList(_getFiltered(AlertCategory.equipment)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatsStrip() {
    final criticalCount = _alerts
        .where((a) => !a.resolved && a.severity == AlertSeverity.critical)
        .length;
    final warningCount = _alerts
        .where((a) => !a.resolved && a.severity == AlertSeverity.warning)
        .length;
    final okCount = _alerts
        .where((a) => !a.resolved && a.severity == AlertSeverity.ok)
        .length;

    return Container(
      color: AppTheme.darkCharcoal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _buildSeverityStatCard(
              count: criticalCount,
              label: 'Critiques',
              color: AppTheme.critical,
              icon: 'error',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSeverityStatCard(
              count: warningCount,
              label: 'Avertissements',
              color: AppTheme.warning,
              icon: 'warning',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSeverityStatCard(
              count: okCount,
              label: 'Info',
              color: AppTheme.success,
              icon: 'info',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityStatCard({
    required int count,
    required String label,
    required Color color,
    required String icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(70), width: 1),
      ),
      child: Row(
        children: [
          CustomIconWidget(iconName: icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
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
            onPressed: _loadAlerts,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertList(List<AlertItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: _showResolved ? 'history' : 'check_circle',
              color: _showResolved ? AppTheme.mutedText : AppTheme.success,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _showResolved ? 'Aucune alerte résolue' : 'Aucune alerte active',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _showResolved
                  ? 'Les alertes résolues apparaîtront ici'
                  : 'Tout est en ordre — aucune alerte à traiter',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                color: AppTheme.mutedText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlerts,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _AlertCard(
          item: items[i],
          canResolve: _canManageAlerts && !items[i].resolved,
          canReopen: _canManageAlerts && items[i].resolved,
          onResolve: () => _resolveAlert(items[i]),
          onReopen: () => _reopenAlert(items[i]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alert Card
// ---------------------------------------------------------------------------
class _AlertCard extends StatelessWidget {
  final AlertItem item;
  final bool canResolve;
  final bool canReopen;
  final VoidCallback onResolve;
  final VoidCallback onReopen;

  const _AlertCard({
    required this.item,
    required this.canResolve,
    required this.canReopen,
    required this.onResolve,
    required this.onReopen,
  });

  Color get _severityColor {
    switch (item.severity) {
      case AlertSeverity.critical:
        return AppTheme.critical;
      case AlertSeverity.warning:
        return AppTheme.warning;
      case AlertSeverity.ok:
        return AppTheme.success;
    }
  }

  Color get _severityBg {
    switch (item.severity) {
      case AlertSeverity.critical:
        return AppTheme.criticalContainer;
      case AlertSeverity.warning:
        return AppTheme.warningContainer;
      case AlertSeverity.ok:
        return AppTheme.successContainer;
    }
  }

  String get _severityLabel {
    switch (item.severity) {
      case AlertSeverity.critical:
        return 'CRITIQUE';
      case AlertSeverity.warning:
        return 'AVERTISSEMENT';
      case AlertSeverity.ok:
        return 'INFO';
    }
  }

  String get _severityIcon {
    switch (item.severity) {
      case AlertSeverity.critical:
        return 'error';
      case AlertSeverity.warning:
        return 'warning';
      case AlertSeverity.ok:
        return 'info';
    }
  }

  String get _categoryIcon {
    switch (item.category) {
      case AlertCategory.insurance:
        return 'description';
      case AlertCategory.inspection:
        return 'fact_check';
      case AlertCategory.maintenance:
        return 'build';
      case AlertCategory.equipment:
        return 'inventory_2';
    }
  }

  String get _categoryLabel {
    switch (item.category) {
      case AlertCategory.insurance:
        return 'Assurance';
      case AlertCategory.inspection:
        return 'Contrôle tech.';
      case AlertCategory.maintenance:
        return 'Maintenance';
      case AlertCategory.equipment:
        return 'Équipement';
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.resolved
              ? AppTheme.outlineVariantLight
              : _severityColor.withAlpha(80),
          width: item.resolved ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(item.resolved ? 5 : 12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with severity badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: item.resolved ? AppTheme.surfaceVariantLight : _severityBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Severity badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: item.resolved
                        ? AppTheme.mutedText.withAlpha(20)
                        : _severityColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: item.resolved
                          ? AppTheme.mutedText.withAlpha(50)
                          : _severityColor.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomIconWidget(
                        iconName: item.resolved
                            ? 'check_circle'
                            : _severityIcon,
                        color: item.resolved
                            ? AppTheme.mutedText
                            : _severityColor,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.resolved ? 'RÉSOLU' : _severityLabel,
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: item.resolved
                              ? AppTheme.mutedText
                              : _severityColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: item.resolved
                          ? AppTheme.mutedText
                          : _severityColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Category + vehicle chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(180),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomIconWidget(
                        iconName: _categoryIcon,
                        color: AppTheme.mutedText,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.vehicleName.isNotEmpty
                            ? item.vehicleName
                            : _categoryLabel,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 11,
                          color: AppTheme.mutedText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.subtitle,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    color: item.resolved
                        ? AppTheme.mutedText
                        : AppTheme.darkCharcoal,
                  ),
                ),
                if (item.detail != null && item.detail!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariantLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'info_outline',
                          color: AppTheme.mutedText,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.detail!,
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

                // Resolved info
                if (item.resolved && item.resolvedAt != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'check_circle',
                        color: AppTheme.success,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Résolu ${_formatDate(item.resolvedAt)}',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 11,
                          color: AppTheme.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],

                if (canResolve || canReopen) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (canResolve)
                        _ResolveButton(onResolve: onResolve)
                      else if (canReopen)
                        TextButton.icon(
                          onPressed: onReopen,
                          icon: CustomIconWidget(
                            iconName: 'restore',
                            color: AppTheme.primary,
                            size: 16,
                          ),
                          label: Text(
                            'Réactiver',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 12,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
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

// ---------------------------------------------------------------------------
// Resolve button with confirmation
// ---------------------------------------------------------------------------
class _ResolveButton extends StatefulWidget {
  final VoidCallback onResolve;

  const _ResolveButton({required this.onResolve});

  @override
  State<_ResolveButton> createState() => _ResolveButtonState();
}

class _ResolveButtonState extends State<_ResolveButton> {
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    if (!_confirming) {
      return TextButton.icon(
        onPressed: () => setState(() => _confirming = true),
        icon: CustomIconWidget(
          iconName: 'check_circle_outline',
          color: AppTheme.success,
          size: 16,
        ),
        label: Text(
          'Marquer comme résolu',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            color: AppTheme.success,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Confirmer ?',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            color: AppTheme.mutedText,
          ),
        ),
        const SizedBox(width: 6),
        TextButton(
          onPressed: () => setState(() => _confirming = false),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
          ),
          child: Text(
            'Non',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              color: AppTheme.mutedText,
            ),
          ),
        ),
        const SizedBox(width: 4),
        ElevatedButton(
          onPressed: () {
            setState(() => _confirming = false);
            widget.onResolve();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(
            'Oui, résoudre',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
