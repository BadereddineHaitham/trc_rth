import 'package:flutter/material.dart';

import '../../../../core/app_export.dart';

class ParkKpiStripWidget extends StatelessWidget {
  final int totalVehicles;
  final int operational;
  final int maintenance;
  final int outOfService;
  final int totalAlerts;
  final int fixedEquipment;

  const ParkKpiStripWidget({
    super.key,
    required this.totalVehicles,
    required this.operational,
    required this.maintenance,
    required this.outOfService,
    required this.totalAlerts,
    required this.fixedEquipment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.darkCharcoal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          // Main stats row
          Row(
            children: [
              _KpiCard(
                value: '$totalVehicles',
                label: 'Véhicules',
                icon: 'fire_truck',
                color: Colors.white,
                iconColor: AppTheme.primary,
                bgColor: Colors.white.withAlpha(20),
              ),
              const SizedBox(width: 8),
              _KpiCard(
                value: '$operational',
                label: 'Opérationnels',
                icon: 'check_circle',
                color: const Color(0xFF4ADE80),
                iconColor: const Color(0xFF4ADE80),
                bgColor: const Color(0xFF4ADE80).withAlpha(26),
              ),
              const SizedBox(width: 8),
              _KpiCard(
                value: '$maintenance',
                label: 'Maintenance',
                icon: 'build',
                color: const Color(0xFFFBBF24),
                iconColor: const Color(0xFFFBBF24),
                bgColor: const Color(0xFFFBBF24).withAlpha(26),
              ),
              const SizedBox(width: 8),
              _KpiCard(
                value: '$outOfService',
                label: 'Hors service',
                icon: 'cancel',
                color: const Color(0xFFF87171),
                iconColor: const Color(0xFFF87171),
                bgColor: const Color(0xFFF87171).withAlpha(26),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Secondary row
          Row(
            children: [
              _KpiCard(
                value: '$totalAlerts',
                label: 'Alertes actives',
                icon: 'warning_amber',
                color: const Color(0xFFFBBF24),
                iconColor: const Color(0xFFFBBF24),
                bgColor: const Color(0xFFFBBF24).withAlpha(26),
                flex: 2,
              ),
              const SizedBox(width: 8),
              _KpiCard(
                value: '$fixedEquipment',
                label: 'Équip. fixes',
                icon: 'settings',
                color: Colors.white,
                iconColor: Colors.white.withAlpha(153),
                bgColor: Colors.white.withAlpha(15),
                flex: 2,
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(38),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.primary.withAlpha(77),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomIconWidget(
                        iconName: 'sync',
                        color: AppTheme.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Synchronisé\n12:08',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 10,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
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

class _KpiCard extends StatelessWidget {
  final String value;
  final String label;
  final String icon;
  final Color color;
  final Color iconColor;
  final Color bgColor;
  final int flex;

  const _KpiCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.bgColor,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(51), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CustomIconWidget(iconName: icon, color: iconColor, size: 14),
                const Spacer(),
                Text(
                  value,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 10,
                color: color.withAlpha(191),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
