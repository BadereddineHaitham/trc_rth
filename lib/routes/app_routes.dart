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

class AppRoutes {
  static const String initial = '/';
  static const String splashScreen = '/splash-screen';
  static const String qrScannerScreen = '/qr-scanner-screen';
  static const String parkHomeScreen = '/park-home-screen';
  static const String vehicleDetailsScreen = '/vehicle-details-screen';
  static const String adminLoginScreen = '/admin-login-screen';
  static const String adminDashboardScreen = '/admin-dashboard-screen';
  static const String superAdminDashboardScreen =
      '/superadmin-dashboard-screen';
  static const String equipmentDefinitionsScreen =
      '/equipment-definitions-screen';
  static const String alertsScreen = '/alerts-screen';
  static const String userManagementScreen = '/user-management-screen';
  static const String profileScreen = '/profile-screen';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.initial,
  routes: [
    GoRoute(
      path: AppRoutes.initial,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SplashScreen(),
        transitionDuration: const Duration(milliseconds: 120),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
            ),
            child: child,
          );
        },
      ),
    ),
    GoRoute(
      path: AppRoutes.splashScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SplashScreen(),
        transitionDuration: const Duration(milliseconds: 120),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.fastOutSlowIn,
              ),
              child: child,
            ),
      ),
    ),
    GoRoute(
      path: AppRoutes.qrScannerScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const QrScannerScreen(),
        transitionDuration: const Duration(milliseconds: 120),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
            ),
            child: child,
          );
        },
      ),
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
        return CustomTransitionPage(
          key: state.pageKey,
          child: ParkHomeScreen(role: role, parkId: parkId),
          transitionDuration: const Duration(milliseconds: 120),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.fastOutSlowIn,
              ),
              child: child,
            );
          },
        );
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
        return CustomTransitionPage(
          key: state.pageKey,
          child: VehicleDetailsScreen(
            vehicleId: vehicleId,
            role: role,
            initialVehicle: initialVehicle,
          ),
          transitionDuration: const Duration(milliseconds: 120),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.fastOutSlowIn,
              ),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: AppRoutes.adminLoginScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const AdminLoginScreen(),
        opaque: true,
        barrierColor: const Color(0xFFF5F7F9),
        transitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.fastOutSlowIn,
              ),
              child: child,
            ),
      ),
    ),
    GoRoute(
      path: AppRoutes.adminDashboardScreen,
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, String>?;
        final role = extra?['role'] ?? 'Admin';
        final username = extra?['username'] ?? 'admin';
        return CustomTransitionPage(
          key: state.pageKey,
          child: AdminDashboardScreen(role: role, username: username),
          transitionDuration: const Duration(milliseconds: 120),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.fastOutSlowIn,
              ),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: AppRoutes.superAdminDashboardScreen,
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, String>?;
        final username = extra?['username'] ?? 'superadmin';
        return CustomTransitionPage(
          key: state.pageKey,
          child: SuperAdminDashboardScreen(username: username),
          transitionDuration: const Duration(milliseconds: 120),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.fastOutSlowIn,
              ),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: AppRoutes.equipmentDefinitionsScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const EquipmentDefinitionsScreen(),
        transitionDuration: const Duration(milliseconds: 120),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
            ),
            child: child,
          );
        },
      ),
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
        return CustomTransitionPage(
          key: state.pageKey,
          child: AlertsScreen(role: role),
          transitionDuration: const Duration(milliseconds: 120),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.fastOutSlowIn,
              ),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: AppRoutes.userManagementScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const UserManagementScreen(),
        transitionDuration: const Duration(milliseconds: 120),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
            ),
            child: child,
          );
        },
      ),
    ),
    GoRoute(
      path: AppRoutes.profileScreen,
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, String>?;
        final role = extra?['role'] ?? 'User';
        final username = extra?['username'] ?? 'utilisateur';
        return CustomTransitionPage(
          key: state.pageKey,
          child: ProfileScreen(role: role, username: username),
          transitionDuration: const Duration(milliseconds: 120),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.fastOutSlowIn,
              ),
              child: child,
            );
          },
        );
      },
    ),
  ],
);

