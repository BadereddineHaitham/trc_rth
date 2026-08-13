import 'package:flutter/material.dart';

import '../../../../core/app_export.dart';

class AdminVehicleStatusListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> vehicles;
  final Function(String) onVehicleTap;

  const AdminVehicleStatusListWidget({
    super.key,
    required this.vehicles,
    required this.onVehicleTap,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'operational':
        return AppTheme.success;
      case 'maintenance':
        return AppTheme.warning;
      case 'out_of_service':
        return AppTheme.critical;
      default:
        return AppTheme.mutedText;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'operational':
        return 'OPÉ.';
      case 'maintenance':
        return 'MAINT.';
      case 'out_of_service':
        return 'H.S.';
      default:
        return 'IND.';
    }
  }

  Color _docColor(String docStatus) {
    switch (docStatus) {
      case 'expired':
        return AppTheme.critical;
      case 'expiring':
        return AppTheme.warning;
      default:
        return AppTheme.success;
    }
  }

  String _docIcon(String docStatus) {
    switch (docStatus) {
      case 'expired':
        return 'error';
      case 'expiring':
        return 'schedule';
      default:
        return 'verified';
    }
  }

  String _vehicleIdFromName(String name) {
    final map = {
      'VMR 80 N°1': 'vmr80-1',
      'VMR 80 N°2': 'vmr80-2',
      'VMR 115 N°1': 'vmr115-1',
      'VMR 115 N°2': 'vmr115-2',
      'ISUZU': 'isuzu-1',
      'ASTRA': 'astra-1',
    };
    return map[name] ?? 'vmr80-2';
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
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceVariantLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Véhicule',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    'Statut',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    'Ass.',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    'CT',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedText,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 32),
              ],
            ),
          ),

          // Vehicle rows
          ...vehicles.asMap().entries.map((entry) {
            final i = entry.key;
            final v = entry.value;
            final isLast = i == vehicles.length - 1;

            final vId = (v['id'] as String?) ?? _vehicleIdFromName((v['name'] as String?) ?? '');
            final vName = (v['name'] as String?)?.trim() ?? 'Véhicule';
            final vMatricule = (v['matricule'] as String?) ?? '—';
            final vStatus = (v['status'] as String?) ?? 'operational';
            final statusColor = _statusColor(vStatus);

            final rawMissing = v['missing'] ?? v['missing_equipment'];
            final missing = rawMissing is int ? rawMissing : (rawMissing is num ? rawMissing.toInt() : 0);

            final insStr = (v['insurance'] as String?) ?? 'valid';
            final inspStr = (v['inspection'] as String?) ?? 'valid';

            return Column(
              children: [
                InkWell(
                  onTap: () => onVehicleTap(vId),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        // Name + matricule
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vName,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkCharcoal,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    vMatricule,
                                    style: GoogleFonts.ibmPlexMono(
                                      fontSize: 10,
                                      color: AppTheme.mutedText,
                                    ),
                                  ),
                                  if (missing > 0) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.criticalContainer,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        '-$missing',
                                        style: GoogleFonts.ibmPlexMono(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.critical,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Status badge
                        SizedBox(
                          width: 60,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(26),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _statusLabel(vStatus),
                                    style: GoogleFonts.ibmPlexSans(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Insurance
                        SizedBox(
                          width: 36,
                          child: Center(
                            child: CustomIconWidget(
                              iconName: _docIcon(insStr),
                              color: _docColor(insStr),
                              size: 18,
                            ),
                          ),
                        ),

                        // Inspection
                        SizedBox(
                          width: 36,
                          child: Center(
                            child: CustomIconWidget(
                              iconName: _docIcon(inspStr),
                              color: _docColor(inspStr),
                              size: 18,
                            ),
                          ),
                        ),

                        // Chevron
                        SizedBox(
                          width: 32,
                          child: Center(
                            child: CustomIconWidget(
                              iconName: 'chevron_right',
                              color: AppTheme.mutedText,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  const Divider(height: 1, indent: 14, endIndent: 14),
              ],
            );
          }),
        ],
      ),
    );
  }
}
