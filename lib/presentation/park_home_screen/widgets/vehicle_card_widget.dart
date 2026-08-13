import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/app_export.dart';

class VehicleCardWidget extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final VoidCallback onTap;

  const VehicleCardWidget({
    super.key,
    required this.vehicle,
    required this.onTap,
  });

  String get _name => (vehicle['name'] as String?)?.trim() ?? 'Véhicule';
  String get _type =>
      (vehicle['vehicle_type'] as String?) ??
      (vehicle['type'] as String?) ??
      'Spécialisé';
  String get _matricule =>
      (vehicle['matricule'] as String?) ?? (vehicle['id'] as String?) ?? '—';

  VehicleStatus get _status {
    final statusStr = (vehicle['status'] as String?) ?? 'operational';
    switch (statusStr) {
      case 'operational':
        return VehicleStatus.operational;
      case 'maintenance':
        return VehicleStatus.maintenance;
      case 'out_of_service':
        return VehicleStatus.outOfService;
      default:
        return VehicleStatus.unavailable;
    }
  }

  String get _insuranceExpiry =>
      (vehicle['insurance_expiry'] as String?) ??
      (vehicle['insuranceExpiry'] as String?) ??
      '';

  String get _inspectionExpiry =>
      (vehicle['inspection_expiry'] as String?) ??
      (vehicle['inspectionExpiry'] as String?) ??
      '';

  int get _missingEquipment {
    final val = vehicle['missing_equipment'] ?? vehicle['missingEquipment'];
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  bool get _hasAlerts =>
      _missingEquipment > 0 ||
      _isDocumentExpiringSoon(_insuranceExpiry) ||
      _isDocumentExpiringSoon(_inspectionExpiry);

  bool _isDocumentExpiringSoon(String dateStr) {
    if (dateStr.isEmpty) return false;
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      return date.difference(now).inDays < 45;
    } catch (_) {
      return false;
    }
  }

  bool _isDocumentExpired(String dateStr) {
    if (dateStr.isEmpty) return false;
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      return date.isBefore(now);
    } catch (_) {
      return false;
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'Non renseigné';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final insuranceExpired = _isDocumentExpired(_insuranceExpiry);
    final inspectionExpired = _isDocumentExpired(_inspectionExpiry);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppTheme.primary.withAlpha(20),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _status == VehicleStatus.outOfService
                  ? AppTheme.critical.withAlpha(77)
                  : _status == VehicleStatus.maintenance
                  ? AppTheme.warning.withAlpha(77)
                  : AppTheme.outlineVariantLight,
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D17202A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                decoration: BoxDecoration(
                  color: _status.headerBgColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(11),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(38),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: CustomIconWidget(
                          iconName: 'fire_truck',
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _type,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 11,
                              color: Colors.white.withAlpha(179),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(status: _status),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  children: [
                    // Matricule row
                    Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'badge',
                          color: AppTheme.mutedText,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _matricule,
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkCharcoal,
                          ),
                        ),
                        const Spacer(),
                        if (_hasAlerts)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.criticalContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CustomIconWidget(
                                  iconName: 'warning',
                                  color: AppTheme.critical,
                                  size: 12,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '$_missingEquipment manquant(s)',
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.critical,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Document status row
                    Row(
                      children: [
                        Expanded(
                          child: _DocStatusChip(
                            label: 'Assurance',
                            date: _formatDate(_insuranceExpiry),
                            isExpired: insuranceExpired,
                            isExpiringSoon:
                                !insuranceExpired &&
                                _isDocumentExpiringSoon(_insuranceExpiry),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _DocStatusChip(
                            label: 'CT',
                            date: _formatDate(_inspectionExpiry),
                            isExpired: inspectionExpired,
                            isExpiringSoon:
                                !inspectionExpired &&
                                _isDocumentExpiringSoon(_inspectionExpiry),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocStatusChip extends StatelessWidget {
  final String label;
  final String date;
  final bool isExpired;
  final bool isExpiringSoon;

  const _DocStatusChip({
    required this.label,
    required this.date,
    required this.isExpired,
    required this.isExpiringSoon,
  });

  Color get _bgColor {
    if (isExpired) return AppTheme.criticalContainer;
    if (isExpiringSoon) return AppTheme.warningContainer;
    return AppTheme.surfaceVariantLight;
  }

  Color get _textColor {
    if (isExpired) return AppTheme.critical;
    if (isExpiringSoon) return AppTheme.warning;
    return AppTheme.secondaryText;
  }

  String get _icon {
    if (isExpired) return 'error';
    if (isExpiringSoon) return 'schedule';
    return 'verified';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          CustomIconWidget(iconName: _icon, color: _textColor, size: 12),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 9,
                    color: _textColor.withAlpha(204),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  date,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final VehicleStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(51),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            status.shortName,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

enum VehicleStatus {
  operational('Opérationnel', 'OPÉ.', AppTheme.success),
  maintenance('En maintenance', 'MAINT.', AppTheme.warning),
  outOfService('Hors service', 'H.S.', AppTheme.critical),
  unavailable('Indisponible', 'IND.', AppTheme.mutedText);

  final String fullName;
  final String shortName;
  final Color headerBgColor;

  const VehicleStatus(this.fullName, this.shortName, this.headerBgColor);
}

