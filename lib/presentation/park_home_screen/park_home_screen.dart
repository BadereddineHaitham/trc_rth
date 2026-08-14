import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_export.dart';
import '../../services/supabase_service.dart';
import '../profile_screen/profile_screen.dart';
import './widgets/fixed_equipment_card_widget.dart';
import './widgets/fixed_equipment_maintenance_modal.dart';
import './widgets/park_alert_banner_widget.dart';
import './widgets/park_kpi_strip_widget.dart';
import './widgets/vehicle_card_widget.dart';

class ParkHomeScreen extends StatefulWidget {
  final String role;
  final String? parkId;

  const ParkHomeScreen({
    super.key,
    this.role = 'Admin',
    this.parkId,
  });

  @override
  State<ParkHomeScreen> createState() => _ParkHomeScreenState();
}

class _ParkHomeScreenState extends State<ParkHomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentNavIndex = 0;
  int _fixesSubTabIndex = 0; // 0 = USD, 1 = Moto Pompe
  late final TabController _tabController;
  final _svc = SupabaseService.instance;

  List<Map<String, dynamic>> _vehicleMaps = [];
  List<Map<String, dynamic>> _fixedEquipmentMaps = [];
  List<Map<String, dynamic>> _alertMaps = [];
  bool _isLoading = true;
  String? _errorMsg;

  List<Map<String, dynamic>> get _usdEquipments => _fixedEquipmentMaps
      .where((e) =>
          (e['category'] as String? ?? '').toUpperCase().contains('USD'))
      .toList();

  List<Map<String, dynamic>> get _motoPompeEquipments => _fixedEquipmentMaps
      .where((e) =>
          !(e['category'] as String? ?? '').toUpperCase().contains('USD'))
      .toList();

  RealtimeChannel? _vehiclesChannel;
  RealtimeChannel? _alertsChannel;
  RealtimeChannel? _fixedEquipChannel;

  bool get _isSuperAdmin => widget.role == 'Super Admin';
  bool get _isAdmin => widget.role == 'Admin';
  bool get _canEdit => _isSuperAdmin || _isAdmin;
  bool get _isViewer => widget.role == 'Viewer' || widget.role == 'User';

  int get _operationalCount =>
      _vehicleMaps.where((v) => v['status'] == 'operational').length;
  int get _maintenanceCount =>
      _vehicleMaps.where((v) => v['status'] == 'maintenance').length;
  int get _outOfServiceCount =>
      _vehicleMaps.where((v) => v['status'] == 'out_of_service').length;
  int get _totalAlerts =>
      _alertMaps.where((a) => a['dismissed'] == false).length;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _vehiclesChannel?.unsubscribe();
    _alertsChannel?.unsubscribe();
    _fixedEquipChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final results = await Future.wait([
        _svc.getVehicles(parkId: widget.parkId),
        _svc.getFixedEquipment(parkId: widget.parkId),
        _svc.getAlerts(dismissed: false),
      ]);
      if (mounted) {
        setState(() {
          _vehicleMaps = results[0];
          _fixedEquipmentMaps = results[1];
          _alertMaps = results[2];
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
        .channel('park_vehicles')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vehicles',
          callback: (_) => _loadData(),
        )
        .subscribe();

    _alertsChannel = _svc.client
        .channel('park_alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'alerts',
          callback: (_) => _loadData(),
        )
        .subscribe();

    _fixedEquipChannel = _svc.client
        .channel('park_fixed_equip')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'fixed_equipment',
          callback: (_) => _loadData(),
        )
        .subscribe();
  }

  void _showAddVehicleSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddVehicleSheet(
        onSave: (data) async {
          try {
            await _svc.createVehicle(
              name: data['name'] as String,
              vehicleType: data['type'] as String,
              matricule: data['matricule'] as String,
              status: data['status'] as String,
              generalRemark: data['remarque'] as String? ?? '',
              battery: data['battery'] as String? ?? '',
              wheelRef: data['wheelRef'] as String? ?? '',
            );
            await _loadData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Véhicule "${data['name']}" ajouté avec succès',
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

  void _showAddFixedEquipmentSheet({String? presetCategory}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddFixedEquipmentSheet(
        presetCategory: presetCategory,
        onSave: (data) async {
          try {
            await _svc.createFixedEquipment(
              name: data['name'] as String,
              category: data['category'] as String,
              location: data['location'] as String,
              status: data['status'] as String,
              parkId: widget.parkId,
              lastInspection: data['lastInspection'] as String?,
            );
            await _loadData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Équipement "${data['name']}" ajouté',
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

  void _showAddUSDEquipmentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddUSDEquipmentSheet(
        onSave: (data) async {
          try {
            await _svc.createFixedEquipment(
              name: data['name'] as String,
              category: 'USD',
              location: data['location'] as String,
              status: data['status'] as String,
              parkId: widget.parkId,
              lastInspection: data['lastInspection'] as String?,
              usdDetails: data['usdDetails'] as Map<String, dynamic>?,
            );
            await _loadData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Équipement USD "${data['name']}" ajouté avec succès',
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

  Widget _buildSubTabItem({
    required int index,
    required String label,
    required String icon,
  }) {
    final isSelected = _fixesSubTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _fixesSubTabIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
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
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFixedEquipmentMaintenanceModal(Map<String, dynamic> equipment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FixedEquipmentMaintenanceModal(
        equipment: equipment,
        canEdit: _canEdit,
        onDataChanged: _loadData,
      ),
    );
  }

  Future<void> _deleteFixedEquipment(Map<String, dynamic> equipment) async {
    final id = equipment['id'] as String?;
    final name = (equipment['name'] as String?) ?? 'cet équipement';
    if (id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'équipement'),
        content: Text('Supprimer "$name" définitivement ?'),
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
      await _svc.deleteFixedEquipment(id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$name" supprimé',
                style: GoogleFonts.ibmPlexSans(color: Colors.white)),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e',
                style: GoogleFonts.ibmPlexSans(color: Colors.white)),
            backgroundColor: AppTheme.critical,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(theme, innerBoxIsScrolled),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.mutedText,
                indicatorColor: AppTheme.primary,
                indicatorWeight: 2.5,
                tabs: [
                  Tab(
                    icon: CustomIconWidget(
                      iconName: 'fire_truck',
                      color: _tabController.index == 0
                          ? AppTheme.primary
                          : AppTheme.mutedText,
                      size: 18,
                    ),
                    text: 'Mobiles (${_vehicleMaps.length})',
                  ),
                  Tab(
                    icon: CustomIconWidget(
                      iconName: 'fire_extinguisher',
                      color: _tabController.index == 1
                          ? AppTheme.primary
                          : AppTheme.mutedText,
                      size: 18,
                    ),
                    text: 'Fixes (${_fixedEquipmentMaps.length})',
                  ),
                ],
              ),
            ),
          ),
        ],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMsg != null
            ? _buildError()
            : _buildBody(theme, isTablet),
      ),
      bottomNavigationBar: _buildBottomNav(theme),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final onFixesTab = _tabController.index == 1;
          final canShowFab = onFixesTab ? _canEdit : _isSuperAdmin;
          if (!canShowFab) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: onFixesTab
                ? (_fixesSubTabIndex == 0
                    ? _showAddUSDEquipmentSheet
                    : () => _showAddFixedEquipmentSheet(presetCategory: 'Moto Pompe'))
                : _showAddVehicleSheet,
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            icon: CustomIconWidget(
              iconName: 'add',
              color: Colors.white,
              size: 22,
            ),
            label: Text(
              onFixesTab
                  ? (_fixesSubTabIndex == 0 ? 'Ajouter USD' : 'Ajouter Moto Pompe')
                  : 'Véhicule',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                color: AppTheme.darkCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMsg ?? '',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                color: AppTheme.mutedText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: CustomIconWidget(
                iconName: 'refresh',
                color: Colors.white,
                size: 18,
              ),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(ThemeData theme, bool innerBoxIsScrolled) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: AppTheme.darkCharcoal,
      foregroundColor: Colors.white,
      scrolledUnderElevation: 2,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: Navigator.canPop(context)
          ? IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Retour',
            )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Parc RTH',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withAlpha(40)),
            ),
            child: Text(
              _isSuperAdmin
                  ? 'Super Admin'
                  : _isViewer
                  ? 'Lecture'
                  : 'Admin',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 11,
                color: Colors.white.withAlpha(220),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (!_isViewer)
          IconButton(
            icon: CustomIconWidget(
              iconName: 'account_circle',
              color: Colors.white,
              size: 24,
            ),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
        IconButton(
          icon: CustomIconWidget(
            iconName: 'refresh',
            color: Colors.white,
            size: 20,
          ),
          onPressed: _loadData,
          tooltip: 'Actualiser',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBody(ThemeData theme, bool isTablet) {
    final criticalAlerts = _alertMaps
        .where((a) => a['severity'] == 'critical' && a['dismissed'] == false)
        .toList();

    return Column(
      children: [
        if (criticalAlerts.isNotEmpty)
          ParkAlertBannerWidget(
            expiredDocCount:
                criticalAlerts.where((a) => a['type'] == 'expired_doc').length,
            missingEquipCount: criticalAlerts
                .where((a) => a['type'] == 'missing_equip')
                .length,
          ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // ── Tab 0: Mobiles ────────────────────────────────────────────
              RefreshIndicator(
                onRefresh: _loadData,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: ParkKpiStripWidget(
                        totalVehicles: _vehicleMaps.length,
                        operational: _operationalCount,
                        maintenance: _maintenanceCount,
                        outOfService: _outOfServiceCount,
                        totalAlerts: _totalAlerts,
                        fixedEquipment: _fixedEquipmentMaps.length,
                      ),
                    ),
                    _vehicleMaps.isEmpty
                        ? SliverFillRemaining(
                            child: Center(
                              child: Text(
                                'Aucun véhicule mobile',
                                style: GoogleFonts.ibmPlexSans(
                                  color: AppTheme.mutedText,
                                ),
                              ),
                            ),
                          )
                        : isTablet
                        ? SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1.6,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) => VehicleCardWidget(
                                  vehicle: _vehicleMaps[i],
                                  onTap: () => context.push(
                                    AppRoutes.vehicleDetailsScreen,
                                    extra: {
                                      'vehicleId': _vehicleMaps[i]['id'] as String,
                                      'role': widget.role,
                                    },
                                  ),
                                ),
                                childCount: _vehicleMaps.length,
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: VehicleCardWidget(
                                    vehicle: _vehicleMaps[i],
                                    onTap: () => context.push(
                                      AppRoutes.vehicleDetailsScreen,
                                      extra: {
                                        'vehicleId': _vehicleMaps[i]['id'] as String,
                                        'role': widget.role,
                                      },
                                    ),
                                  ),
                                ),
                                childCount: _vehicleMaps.length,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
              // ── Tab 1: Fixes ──────────────────────────────────────────────
              RefreshIndicator(
                onRefresh: _loadData,
                child: Column(
                  children: [
                    // Sub-tabs for USD / Moto Pompe
                    Container(
                      color: AppTheme.surfaceVariantLight,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSubTabItem(
                              index: 0,
                              label: 'USD (${_usdEquipments.length})',
                              icon: 'shield',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSubTabItem(
                              index: 1,
                              label: 'Moto Pompe (${_motoPompeEquipments.length})',
                              icon: 'settings',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: () {
                        final currentList = _fixesSubTabIndex == 0
                            ? _usdEquipments
                            : _motoPompeEquipments;
                        final subTabName =
                            _fixesSubTabIndex == 0 ? 'USD' : 'Moto Pompe';

                        if (currentList.isEmpty) {
                          return ListView(
                            children: [
                              const SizedBox(height: 60),
                              Center(
                                child: Column(
                                  children: [
                                    CustomIconWidget(
                                      iconName: _fixesSubTabIndex == 0
                                          ? 'shield'
                                          : 'settings',
                                      color: AppTheme.mutedText,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Aucun équipement $subTabName',
                                      style: GoogleFonts.ibmPlexSans(
                                        color: AppTheme.mutedText,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (_canEdit) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Appuyez sur + pour ajouter un équipement $subTabName',
                                        style: GoogleFonts.ibmPlexSans(
                                          color: AppTheme.mutedText,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: currentList.length,
                          itemBuilder: (ctx, i) {
                            final item = currentList[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: FixedEquipmentCardWidget(
                                equipment: item,
                                onTap: () =>
                                    _openFixedEquipmentMaintenanceModal(item),
                                onMaintenance: () =>
                                    _openFixedEquipmentMaintenanceModal(item),
                                onDelete: _canEdit
                                    ? () => _deleteFixedEquipment(item)
                                    : null,
                              ),
                            );
                          },
                        );
                      }(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav(ThemeData theme) {
    return NavigationBar(
      selectedIndex: _currentNavIndex,
      onDestinationSelected: (index) {
        setState(() => _currentNavIndex = index);
        if (index == 1) {
          context.go(
            AppRoutes.alertsScreen,
            extra: {'role': widget.role},
          );
        } else if (index == 2) {
          context.go(
            AppRoutes.profileScreen,
            extra: {'role': widget.role, 'username': 'utilisateur'},
          );
        }
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Accueil',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: _totalAlerts > 0,
            label: Text('$_totalAlerts'),
            child: const Icon(Icons.notifications_outlined),
          ),
          selectedIcon: const Icon(Icons.notifications),
          label: 'Alertes',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
    );
  }
}

// ── TabBar SliverPersistentHeader Delegate ────────────────────────────────────
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
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => tabBar != oldDelegate.tabBar;
}

// ── Add Vehicle Sheet ─────────────────────────────────────────────────────────
class _AddVehicleSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const _AddVehicleSheet({required this.onSave});

  @override
  State<_AddVehicleSheet> createState() => _AddVehicleSheetState();
}

class _AddVehicleSheetState extends State<_AddVehicleSheet> {
  final _nameCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _matriculeCtrl = TextEditingController();
  final _remarqueCtrl = TextEditingController();
  final _batteryCtrl = TextEditingController();
  final _wheelRefCtrl = TextEditingController();
  String _selectedStatus = 'operational';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _typeCtrl.dispose();
    _matriculeCtrl.dispose();
    _remarqueCtrl.dispose();
    _batteryCtrl.dispose();
    _wheelRefCtrl.dispose();
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
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nom du véhicule *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _typeCtrl,
              decoration: const InputDecoration(
                labelText: 'Type (VMR 80, VMR 115...)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _matriculeCtrl,
              decoration: const InputDecoration(labelText: 'Matricule'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _batteryCtrl,
              decoration: const InputDecoration(
                labelText: 'Batterie',
                hintText: 'ex: 12V 100Ah',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wheelRefCtrl,
              decoration: const InputDecoration(
                labelText: 'Réf. de roue',
                hintText: 'ex: 315/80 R22.5',
              ),
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
              controller: _remarqueCtrl,
              decoration: const InputDecoration(labelText: 'Remarque'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving
                    ? null
                    : () async {
                        if (_nameCtrl.text.trim().isEmpty) return;
                        setState(() => _saving = true);
                        Navigator.pop(context);
                        await widget.onSave({
                          'name': _nameCtrl.text.trim(),
                          'type': _typeCtrl.text.trim(),
                          'matricule': _matriculeCtrl.text.trim(),
                          'status': _selectedStatus,
                          'remarque': _remarqueCtrl.text.trim(),
                          'battery': _batteryCtrl.text.trim(),
                          'wheelRef': _wheelRefCtrl.text.trim(),
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

// ── Add Fixed Equipment Sheet ─────────────────────────────────────────────────
class _AddFixedEquipmentSheet extends StatefulWidget {
  final String? presetCategory;
  final Function(Map<String, dynamic>) onSave;
  const _AddFixedEquipmentSheet({
    this.presetCategory,
    required this.onSave,
  });

  @override
  State<_AddFixedEquipmentSheet> createState() =>
      _AddFixedEquipmentSheetState();
}

class _AddFixedEquipmentSheetState extends State<_AddFixedEquipmentSheet> {
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  String _selectedStatus = 'operational';
  DateTime? _lastInspection;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.presetCategory != null && widget.presetCategory!.isNotEmpty) {
      _categoryCtrl.text = widget.presetCategory!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastInspection ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _lastInspection = picked);
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.presetCategory != null && widget.presetCategory!.isNotEmpty
        ? 'Nouvel équipement — ${widget.presetCategory}'
        : 'Nouvel équipement fixe';

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
                  titleText,
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
              controller: _categoryCtrl,
              decoration: const InputDecoration(
                labelText: 'Catégorie (ex: Moto Pompe, Extincteur...)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Emplacement (ex: Bâtiment A, Zone 2...)',
              ),
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Dernière inspection',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  color: AppTheme.secondaryText,
                ),
              ),
              subtitle: Text(
                _lastInspection != null
                    ? '${_lastInspection!.day.toString().padLeft(2, '0')}/${_lastInspection!.month.toString().padLeft(2, '0')}/${_lastInspection!.year}'
                    : 'Appuyez pour sélectionner',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _lastInspection != null
                      ? AppTheme.darkCharcoal
                      : AppTheme.mutedText,
                ),
              ),
              trailing: const Icon(Icons.calendar_today, size: 18),
              onTap: _pickDate,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving
                    ? null
                    : () async {
                        if (_nameCtrl.text.trim().isEmpty) return;
                        setState(() => _saving = true);
                        Navigator.pop(context);
                        await widget.onSave({
                          'name': _nameCtrl.text.trim(),
                          'category': _categoryCtrl.text.trim().isNotEmpty
                              ? _categoryCtrl.text.trim()
                              : (widget.presetCategory ?? 'Général'),
                          'location': _locationCtrl.text.trim(),
                          'status': _selectedStatus,
                          'lastInspection': _lastInspection != null
                              ? _lastInspection!.toIso8601String().split('T')[0]
                              : null,
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

// ── Add USD Equipment Sheet (LES VANNES / DIVERS B/M) ──────────────────────────
class _AddUSDEquipmentSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const _AddUSDEquipmentSheet({required this.onSave});

  @override
  State<_AddUSDEquipmentSheet> createState() => _AddUSDEquipmentSheetState();
}

class _AddUSDEquipmentSheetState extends State<_AddUSDEquipmentSheet> {
  final _nameCtrl = TextEditingController(text: 'Unité USD');
  final _locationCtrl = TextEditingController();
  String _selectedStatus = 'operational';
  DateTime? _lastInspection;
  bool _saving = false;
  int _selectedCategoryTab = 0; // 0 = LES VANNES, 1 = DIVERS

  final Map<String, String> _usdComponentStates = {
    // LES VANNES (13)
    'Vanne Entrée USD': 'B',
    'Vanne Sortie USD': 'B',
    'Vannes Entrée 1/4 tours — Unité A': 'B',
    'Vannes Entrée 1/4 tours — Unité B': 'B',
    'Vannes Sortie 1/4 tours — Unité A': 'B',
    'Vannes Sortie 1/4 tours — Unité B': 'B',
    'Vanne Régulatrice': 'B',
    'Vanne de remplissage et vidange émulseur — Unité A': 'B',
    'Vanne de remplissage et vidange émulseur — Unité B': 'B',
    'Vanne de remplissage et vidange eau — Unité A': 'B',
    'Vanne de remplissage et vidange eau — Unité B': 'B',
    'Vannes de purge ligne d\'interconnexion — Unité A': 'B',
    'Vannes de purge ligne d\'interconnexion — Unité B': 'B',
    // DIVERS (6)
    'État D\'Unité A': 'B',
    'État D\'Unité B': 'B',
    'Filtre': 'B',
    'Les Manomètres': 'B',
    'Clapet anti-retour': 'B',
    'Autre': 'B',
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastInspection ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _lastInspection = picked);
  }

  @override
  Widget build(BuildContext context) {
    final vannesKeys = [
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

    final diversKeys = [
      'État D\'Unité A',
      'État D\'Unité B',
      'Filtre',
      'Les Manomètres',
      'Clapet anti-retour',
      'Autre',
    ];

    final currentKeys = _selectedCategoryTab == 0 ? vannesKeys : diversKeys;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'Nouvel Équipement USD',
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
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom de l\'Équipement USD *',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Emplacement (ex: Zone USD 1...)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedStatus,
                    decoration: const InputDecoration(labelText: 'Statut Général'),
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
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Dernière inspection',
                      style: GoogleFonts.ibmPlexSans(fontSize: 13),
                    ),
                    subtitle: Text(
                      _lastInspection != null
                          ? '${_lastInspection!.day.toString().padLeft(2, '0')}/${_lastInspection!.month.toString().padLeft(2, '0')}/${_lastInspection!.year}'
                          : 'Appuyez pour sélectionner',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _lastInspection != null
                            ? AppTheme.darkCharcoal
                            : AppTheme.mutedText,
                      ),
                    ),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 16),

                  // ── Category Type Switcher (LES VANNES vs DIVERS) ───────────
                  Text(
                    'Choix de la Catégorie de Composants',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkCharcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCategoryTabBtn(
                          index: 0,
                          title: 'LES VANNES (13)',
                          icon: Icons.water_drop,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCategoryTabBtn(
                          index: 1,
                          title: 'DIVERS (6)',
                          icon: Icons.tune,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Items List with B / M state toggles ────────────────────
                  Container(
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
                            Text(
                              _selectedCategoryTab == 0
                                  ? 'LISTE DES VANNES'
                                  : 'LISTE DIVERS',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'B = Bon état | M = Mauvais état',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 11,
                                color: AppTheme.mutedText,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        ...currentKeys.map(
                          (key) => _buildStateRow(
                            key,
                            _usdComponentStates[key] ?? 'B',
                            (val) => setState(() => _usdComponentStates[key] = val),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              if (_nameCtrl.text.trim().isEmpty) return;
                              setState(() => _saving = true);
                              Navigator.pop(context);
                              await widget.onSave({
                                'name': _nameCtrl.text.trim(),
                                'category': 'USD',
                                'location': _locationCtrl.text.trim(),
                                'status': _selectedStatus,
                                'lastInspection': _lastInspection != null
                                    ? _lastInspection!.toIso8601String().split('T')[0]
                                    : null,
                                'usdDetails': _usdComponentStates,
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
                          : const Text('Enregistrer Équipement USD'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabBtn({
    required int index,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _selectedCategoryTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedCategoryTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.outlineVariantLight,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppTheme.mutedText,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.darkCharcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateRow(
    String label,
    String currentState,
    Function(String) onChanged,
  ) {
    final isGood = currentState == 'B';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.darkCharcoal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              GestureDetector(
                onTap: () => onChanged('B'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isGood ? AppTheme.success : Colors.grey.shade200,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                  ),
                  child: Text(
                    'B — Bon',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isGood ? Colors.white : AppTheme.mutedText,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => onChanged('M'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: !isGood ? AppTheme.critical : Colors.grey.shade200,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                  ),
                  child: Text(
                    'M — Mauvais',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: !isGood ? Colors.white : AppTheme.mutedText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}