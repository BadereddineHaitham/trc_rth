import 'package:flutter/material.dart';

import '../../../../core/app_export.dart';

class VehicleInfoTabWidget extends StatelessWidget {
  final Map<String, dynamic> vehicle;

  const VehicleInfoTabWidget({super.key, required this.vehicle});

  bool _isExpired(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      return date.isBefore(now);
    } catch (_) {
      return false;
    }
  }

  bool _isExpiringSoon(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = date.difference(now).inDays;
      return diff >= 0 && diff < 45;
    } catch (_) {
      return false;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _str(dynamic val) => val is String ? val : '';

  @override
  Widget build(BuildContext context) {
    final insStart = _str(vehicle['insuranceStart']);
    final insExpiry = _str(vehicle['insuranceExpiry']);
    final inspExpiry = _str(vehicle['inspectionExpiry']);
    final oilChange = _str(vehicle['oilChange']);
    final generalRemark = _str(vehicle['generalRemark']);
    final matricule = _str(vehicle['matricule']);
    final type = _str(vehicle['type']);
    final battery = _str(vehicle['battery']);
    final wheelRef = _str(vehicle['wheelRef']);
    final affectation = _str(vehicle['affectation']);

    final insuranceExpired = _isExpired(insExpiry);
    final inspectionExpired = _isExpired(inspExpiry);
    final oilChangeSoon = _isExpiringSoon(oilChange);
    final hasRemark = generalRemark.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Identification card
          _SectionCard(
            title: 'Identification',
            icon: 'badge',
            children: [
              _InfoRow(
                label: 'Matricule',
                value: matricule.isEmpty ? '—' : matricule,
                isMonospace: true,
                isBold: true,
              ),
              const Divider(height: 1),
              _InfoRow(
                label: 'Type de véhicule',
                value: type.isEmpty ? 'Spécialisé' : type,
              ),
              const Divider(height: 1),
              _InfoRow(
                label: 'Batterie',
                value: battery.isEmpty ? '—' : battery,
              ),
              const Divider(height: 1),
              _InfoRow(
                label: 'Réf. de roue',
                value: wheelRef.isEmpty ? '—' : wheelRef,
                isMonospace: true,
              ),
              const Divider(height: 1),
              _InfoRow(label: 'Parc', value: 'Parc RTH — Hassi Messaoud'),
              const Divider(height: 1),
              _InfoRow(
                label: 'Affectation',
                value: affectation.isEmpty ? 'Non spécifiée' : affectation,
                isBold: true,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Administrative documents card
          _SectionCard(
            title: 'Documents administratifs',
            icon: 'description',
            children: [
              // Insurance
              _DocumentRow(
                label: 'Assurance',
                startDate: _formatDate(insStart),
                endDate: _formatDate(insExpiry),
                isExpired: insuranceExpired,
                isExpiringSoon:
                    !insuranceExpired && _isExpiringSoon(insExpiry),
              ),
              const Divider(height: 1),
              // Technical inspection
              _DocumentRow(
                label: 'Contrôle technique',
                endDate: _formatDate(inspExpiry),
                isExpired: inspectionExpired,
                isExpiringSoon:
                    !inspectionExpired && _isExpiringSoon(inspExpiry),
              ),
              const Divider(height: 1),
              // Oil change
              _DocumentRow(
                label: 'Vidange',
                endDate: _formatDate(oilChange),
                isExpired: false,
                isExpiringSoon: oilChangeSoon,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Remarks card
          if (hasRemark)
            _SectionCard(
              title: 'Remarque générale',
              icon: 'comment',
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.warningContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: CustomIconWidget(
                            iconName: 'info',
                            color: AppTheme.warning,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          vehicle['generalRemark'] as String,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 13,
                            color: AppTheme.darkCharcoal,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          if (!hasRemark)
            _SectionCard(
              title: 'Remarque générale',
              icon: 'comment',
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Aucune remarque enregistrée.',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      color: AppTheme.mutedText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: icon,
                  color: AppTheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkCharcoal,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppTheme.outlineVariantLight),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMonospace;
  final bool isBold;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isMonospace = false,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                color: AppTheme.mutedText,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: isMonospace
                  ? GoogleFonts.ibmPlexMono(
                      fontSize: 13,
                      fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                      color: AppTheme.darkCharcoal,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )
                  : GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
                      color: AppTheme.darkCharcoal,
                    ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  final String label;
  final String? startDate;
  final String endDate;
  final bool isExpired;
  final bool isExpiringSoon;

  const _DocumentRow({
    required this.label,
    this.startDate,
    required this.endDate,
    required this.isExpired,
    required this.isExpiringSoon,
  });

  Color get _statusColor {
    if (isExpired) return AppTheme.critical;
    if (isExpiringSoon) return AppTheme.warning;
    return AppTheme.success;
  }

  Color get _bgColor {
    if (isExpired) return AppTheme.criticalContainer;
    if (isExpiringSoon) return AppTheme.warningContainer;
    return AppTheme.successContainer;
  }

  String get _statusText {
    if (isExpired) return 'EXPIRÉ';
    if (isExpiringSoon) return 'BIENTÔT';
    return 'VALIDE';
  }

  String get _statusIcon {
    if (isExpired) return 'error';
    if (isExpiringSoon) return 'schedule';
    return 'verified';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    color: AppTheme.mutedText,
                  ),
                ),
                const SizedBox(height: 3),
                if (startDate != null)
                  Text(
                    '$startDate → $endDate',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkCharcoal,
                    ),
                  )
                else
                  Text(
                    endDate,
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkCharcoal,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomIconWidget(
                  iconName: _statusIcon,
                  color: _statusColor,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  _statusText,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
