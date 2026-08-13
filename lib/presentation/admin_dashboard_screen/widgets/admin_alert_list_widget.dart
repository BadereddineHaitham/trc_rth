import 'package:flutter/material.dart';

import '../../../../core/app_export.dart';

class AdminAlertListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;

  const AdminAlertListWidget({super.key, required this.alerts});

  Color _typeColor(String type) {
    switch (type) {
      case 'critical':
        return AppTheme.critical;
      case 'warning':
        return AppTheme.warning;
      default:
        return const Color(0xFF1E88E5);
    }
  }

  Color _typeBgColor(String type) {
    switch (type) {
      case 'critical':
        return AppTheme.criticalContainer;
      case 'warning':
        return AppTheme.warningContainer;
      default:
        return const Color(0xFFE3F2FD);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariantLight, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0D17202A),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: alerts.asMap().entries.map((entry) {
          final i = entry.key;
          final alert = entry.value;
          final isLast = i == alerts.length - 1;
          final color = _typeColor(alert['type'] as String);
          final bgColor = _typeBgColor(alert['type'] as String);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: CustomIconWidget(
                          iconName: alert['icon'] as String,
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
                            alert['message'] as String,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.darkCharcoal,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              CustomIconWidget(
                                iconName: 'fire_truck',
                                color: AppTheme.mutedText,
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                alert['vehicle'] as String,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 11,
                                  color: AppTheme.mutedText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => context.push(AppRoutes.alertsScreen),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: color.withAlpha(26),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: color.withAlpha(77),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          alert['action'] as String,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
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
}
