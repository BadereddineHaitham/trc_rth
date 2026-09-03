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
    final affectation = (vehicle['affectation'] as String?)?.trim() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppTheme.primary.withAlpha(25),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _status == VehicleStatus.outOfService
                  ? AppTheme.critical.withAlpha(90)
                  : _status == VehicleStatus.maintenance
                  ? AppTheme.warning.withAlpha(90)
                  : AppTheme.outlineVariantLight,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.darkCharcoal.withAlpha(12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // Enhanced Header Banner
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _status.headerBgColor,
                      _status.headerBgColor.withAlpha(220),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: CustomIconWidget(
                          iconName: 'fire_truck',
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                _type,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withAlpha(210),
                                ),
                              ),
                              if (affectation.isNotEmpty) ...[
                                Text(
                                  ' • ',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(180),
                                    fontSize: 10,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    affectation,
                                    style: GoogleFonts.ibmPlexSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: _status),
                  ],
                ),
              ),

              // Card Body
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  children: [
                    // Matricule & Alerts row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.darkCharcoal.withAlpha(12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CustomIconWidget(
                                iconName: 'badge',
                                color: AppTheme.darkCharcoal,
                                size: 13,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _matricule,
                                style: GoogleFonts.ibmPlexMono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.darkCharcoal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Document Status Row (Assurance & Control Technique)
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DocStatusChip(
                            label: 'Contrôle Tech.',
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
