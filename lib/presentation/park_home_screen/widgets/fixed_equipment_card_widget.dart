import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/app_export.dart';

class FixedEquipmentCardWidget extends StatelessWidget {
  final Map<String, dynamic> equipment;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onMaintenance;

  const FixedEquipmentCardWidget({
    super.key,
    required this.equipment,
    this.onDelete,
    this.onTap,
    this.onMaintenance,
  });

  bool get _isOperational =>
      (equipment['status'] as String?) == 'operational';
  bool get _isMaintenance =>
      (equipment['status'] as String?) == 'maintenance';
  bool get _isOutOfService =>
      (equipment['status'] as String?) == 'out_of_service';

  String get _name => (equipment['name'] as String?)?.trim() ?? 'Équipement';
  String get _location => (equipment['location'] as String?) ?? '—';
  String get _category =>
      (equipment['category'] as String?) ??
      (equipment['type'] as String?) ??
      'Général';
  String get _lastInspection =>
      (equipment['last_inspection'] as String?) ??
      (equipment['lastInspection'] as String?) ??
      '';

  Color get _statusBgColor {
    if (_isOperational) return AppTheme.successContainer;
    if (_isMaintenance) return AppTheme.warningContainer;
    if (_isOutOfService) return AppTheme.criticalContainer;
    return AppTheme.surfaceVariantLight;
  }

  Color get _statusTextColor {
    if (_isOperational) return AppTheme.success;
    if (_isMaintenance) return AppTheme.warning;
    if (_isOutOfService) return AppTheme.critical;
    return AppTheme.mutedText;
  }

  String get _statusText {
    if (_isOperational) return 'OPÉRATIONNEL';
    if (_isMaintenance) return 'MAINTENANCE';
    if (_isOutOfService) return 'HORS SERVICE';
    return 'INDISPONIBLE';
  }

  @override
  Widget build(BuildContext context) {
    final isUSD = _category.toUpperCase().contains('USD');
    return GestureDetector(
      onTap: onTap ?? onMaintenance,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isMaintenance
                ? AppTheme.warning.withAlpha(77)
                : _isOutOfService
                ? AppTheme.critical.withAlpha(77)
                : AppTheme.outlineVariantLight,
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D17202A),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isUSD
                          ? AppTheme.primaryContainer
                          : _isMaintenance
                          ? AppTheme.warningContainer
                          : _isOutOfService
                          ? AppTheme.criticalContainer
                          : AppTheme.surfaceVariantLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: CustomIconWidget(
                        iconName: isUSD ? 'shield' : 'settings',
                        color: isUSD
                            ? AppTheme.primary
                            : _isMaintenance
                            ? AppTheme.warning
                            : _isOutOfService
                            ? AppTheme.critical
                            : AppTheme.primary,
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
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkCharcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            CustomIconWidget(
                              iconName: 'location_on',
                              color: AppTheme.mutedText,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                _location,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 11,
                                  color: AppTheme.mutedText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _category,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 11,
                            color: AppTheme.secondaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _statusBgColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: _statusTextColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _statusText,
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: _statusTextColor,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (onDelete != null) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: onDelete,
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: AppTheme.critical,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _lastInspection.isNotEmpty
                            ? 'Insp: ${_formatDate(_lastInspection)}'
                            : 'Non inspecté',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 10,
                          color: AppTheme.mutedText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: AppTheme.outlineVariantLight),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    isUSD ? '🛡️ Unité USD' : '⚙️ Équipement',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      color: AppTheme.mutedText,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: onMaintenance ?? onTap,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomIconWidget(
                            iconName: 'build',
                            color: AppTheme.primary,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Maintenance & Détails',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
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
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
