import 'package:flutter/material.dart';

import '../../../../core/app_export.dart';

class ParkAlertBannerWidget extends StatelessWidget {
  final int expiredDocCount;
  final int missingEquipCount;

  const ParkAlertBannerWidget({
    super.key,
    required this.expiredDocCount,
    required this.missingEquipCount,
  });

  @override
  Widget build(BuildContext context) {
    if (expiredDocCount == 0 && missingEquipCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      color: AppTheme.darkCharcoal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          if (expiredDocCount > 0)
            _AlertItem(
              icon: 'description',
              message:
                  '$expiredDocCount document(s) expiré(s) — action requise',
              severity: 'critical',
              onTap: () => context.push(AppRoutes.alertsScreen),
            ),
          if (expiredDocCount > 0 && missingEquipCount > 0)
            const SizedBox(height: 6),
          if (missingEquipCount > 0)
            _AlertItem(
              icon: 'inventory_2',
              message:
                  '$missingEquipCount équipement(s) manquant(s) dans le parc',
              severity: 'warning',
              onTap: () => context.push(AppRoutes.alertsScreen),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _AlertItem extends StatelessWidget {
  final String icon;
  final String message;
  final String severity;
  final VoidCallback? onTap;

  const _AlertItem({
    required this.icon,
    required this.message,
    required this.severity,
    this.onTap,
  });

  Color get _bgColor => severity == 'critical'
      ? AppTheme.critical.withAlpha(38)
      : AppTheme.warning.withAlpha(38);

  Color get _borderColor => severity == 'critical'
      ? AppTheme.critical.withAlpha(102)
      : AppTheme.warning.withAlpha(102);

  Color get _iconColor =>
      severity == 'critical' ? AppTheme.critical : AppTheme.warning;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor, width: 1),
        ),
        child: Row(
          children: [
            CustomIconWidget(iconName: icon, color: _iconColor, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  color: _iconColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            CustomIconWidget(
              iconName: 'chevron_right',
              color: _iconColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
