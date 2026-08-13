import 'package:flutter/material.dart';

import '../../../../core/app_export.dart';

class AdminKpiGridWidget extends StatelessWidget {
  final List<Map<String, dynamic>> kpiData;
  final String role;

  const AdminKpiGridWidget({
    super.key,
    required this.kpiData,
    this.role = 'Admin',
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: kpiData.length,
      itemBuilder: (ctx, i) => _KpiTile(
        data: kpiData[i],
        index: i,
        role: role,
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final int index;
  final String role;

  const _KpiTile({
    required this.data,
    required this.index,
    required this.role,
  });

  void _onTap(BuildContext context) {
    switch (index) {
      case 0: // Total véhicules
      case 1: // Opérationnels
      case 2: // En maintenance
      case 3: // Hors service
        context.push(AppRoutes.parkHomeScreen, extra: role);
        break;
      case 4: // Alertes équip.
        context.push(
          AppRoutes.alertsScreen,
          extra: {'role': role},
        );
        break;
      case 5: // Docs expirés
        context.push(
          AppRoutes.alertsScreen,
          extra: {'role': role},
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = data['color'] as Color;
    final bgColor = data['bgColor'] as Color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTap(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(40), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A17202A),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: CustomIconWidget(
                    iconName: data['icon'] as String,
                    color: color,
                    size: 16,
                  ),
                ),
              ),
              Text(
                data['value'] as String,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                data['label'] as String,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 10,
                  color: AppTheme.secondaryText,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
