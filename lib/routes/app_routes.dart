import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../presentation/splash_screen/splash_screen.dart';
import '../presentation/qr_scanner_screen/qr_scanner_screen.dart';
import '../presentation/park_home_screen/park_home_screen.dart';
import '../presentation/vehicle_details_screen/vehicle_details_screen.dart';
import '../presentation/admin_login_screen/admin_login_screen.dart';
import '../presentation/admin_dashboard_screen/admin_dashboard_screen.dart';
import '../presentation/superadmin_dashboard_screen/superadmin_dashboard_screen.dart';
import '../presentation/equipment_definitions_screen/equipment_definitions_screen.dart';
import '../presentation/alerts_screen/alerts_screen.dart';
import '../presentation/user_management_screen/user_management_screen.dart';
import '../presentation/profile_screen/profile_screen.dart';
import '../presentation/audit_log_screen/audit_log_screen.dart';

class AppRoutes {
  static const String initial = '/';
  static const String splashScreen = '/splash-screen';
  static const String qrScannerScreen = '/qr-scanner-screen';
  static const String parkHomeScreen = '/park-home-screen';
  static const String vehicleDetailsScreen = '/vehicle-details-screen';
  static const String adminLoginScreen = '/admin-login-screen';
  static const String adminDashboardScreen = '/admin-dashboard-screen';
  static const String superAdminDashboardScreen = '/superadmin-dashboard-screen';
  static const String equipmentDefinitionsScreen = '/equipment-definitions-screen';
  static const String alertsScreen = '/alerts-screen';
  static const String userManagementScreen = '/user-management-screen';
  static const String profileScreen = '/profile-screen';
  static const String auditLogScreen = '/audit-log-screen';
}

Page<T> _noTransition<T>(LocalKey key, Widget child) =>
    NoTransitionPage<T>(key: key, child: child);

Page<T> _slideUp<T>(LocalKey key, Widget child) => CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 160),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      transitionsBuilder: (_, animation, __, c) => SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: FadeTransition(opacity: animation, child: c),
      ),
    );

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.initial,
  routes: [
    GoRoute(
      path: AppRoutes.initial,
      pageBuilder: (context, state) =>
          _noTransition(state.pageKey, const SplashScreen()),
    ),
    GoRoute(
      path: AppRoutes.splashScreen,
      pageBuilder: (context, state) =>
          _noTransition(state.pageKey, const SplashScreen()),
    ),
    GoRoute(
      path: AppRoutes.qrScannerScreen,
      pageBuilder: (context, state) =>
          _slideUp(state.pageKey, const QrScannerScreen()),
    ),
    GoRoute(
      path: AppRoutes.parkHomeScreen,
      pageBuilder: (context, state) {
        String role = 'User';
        String? parkId;
        if (state.extra is Map<String, dynamic>) {
          final map = state.extra as Map<String, dynamic>;
          role = map['role'] as String? ?? 'User';
          parkId = map['parkId'] as String?;
        } else if (state.extra is String) {
          role = state.extra as String;
        }
        return _noTransition(state.pageKey, ParkHomeScreen(role: role, parkId: parkId));
      },
    ),
    GoRoute(
      path: AppRoutes.vehicleDetailsScreen,
      pageBuilder: (context, state) {
        final extra = state.extra;
        String vehicleId = 'vmr80-2';
        String role = 'User';
        Map<String, dynamic>? initialVehicle;
        if (extra is Map<String, String>) {
          vehicleId = extra['vehicleId'] ?? 'vmr80-2';
          role = extra['role'] ?? 'User';
        } else if (extra is Map<String, dynamic>) {
          vehicleId = extra['vehicleId'] as String? ?? 'vmr80-2';
          role = extra['role'] as String? ?? 'User';
          initialVehicle = extra['initialVehicle'] as Map<String, dynamic>?;
        } else if (extra is String && extra.isNotEmpty) {
          vehicleId = extra;
          role = 'User';
        }
        return _slideUp(
          state.pageKey,
          VehicleDetailsScreen(vehicleId: vehicleId, role: role, initialVehicle: initialVehicle),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.adminLoginScreen,
      pageBuilder: (context, state) =>
          _noTransition(state.pageKey, const AdminLoginScreen()),
    ),
    GoRoute(
      path: AppRoutes.adminDashboardScreen,
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, String>?;
        final role = extra?['role'] ?? 'Admin';
        final username = extra?['username'] ?? 'admin';
        return _noTransition(state.pageKey, AdminDashboardScreen(role: role, username: username));
      },
    ),
    GoRoute(
      path: AppRoutes.superAdminDashboardScreen,
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, String>?;
        final username = extra?['username'] ?? 'superadmin';
        return _noTransition(state.pageKey, SuperAdminDashboardScreen(username: username));
      },
    ),
    GoRoute(
      path: AppRoutes.equipmentDefinitionsScreen,
      pageBuilder: (context, state) =>
          _slideUp(state.pageKey, const EquipmentDefinitionsScreen()),
    ),
    GoRoute(
      path: AppRoutes.alertsScreen,
      pageBuilder: (context, state) {
        String role = 'User';
        final extra = state.extra;
        if (extra is Map<String, String>) {
          role = extra['role'] ?? 'User';
        } else if (extra is Map<String, dynamic>) {
          role = extra['role'] as String? ?? 'User';
        } else if (extra is String && extra.isNotEmpty) {
          role = extra;
        }
        return _noTransition(state.pageKey, AlertsScreen(role: role));
      },
    ),
    GoRoute(
      path: AppRoutes.userManagementScreen,
      pageBuilder: (context, state) =>
          _slideUp(state.pageKey, const UserManagementScreen()),
    ),
    GoRoute(
      path: AppRoutes.profileScreen,
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, String>?;
        final role = extra?['role'] ?? 'User';
        final username = extra?['username'] ?? 'utilisateur';
        return _slideUp(state.pageKey, ProfileScreen(role: role, username: username));
      },
    ),
    GoRoute(
      path: AppRoutes.auditLogScreen,
      pageBuilder: (context, state) =>
          _slideUp(state.pageKey, const AuditLogScreen()),
    ),
  ],
);
