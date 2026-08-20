import 'package:flutter/material.dart';

import '../../../../core/app_export.dart';
import '../../../../services/supabase_service.dart';

class VehicleInfoTabWidget extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  final bool canEdit;

  const VehicleInfoTabWidget({
    super.key,
    required this.vehicle,
    this.canEdit = false,
  });

  @override
  State<VehicleInfoTabWidget> createState() => _VehicleInfoTabWidgetState();
}

class _VehicleInfoTabWidgetState extends State<VehicleInfoTabWidget> {
  bool _isSavingPark = false;

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

  void _openEditParkName() {
    final parkId = _str(widget.vehicle['parkId']);
    if (parkId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aucun parc associÃ© Ã  ce vÃ©hicule.',
            style: GoogleFonts.ibmPlexSans(color: Colors.white),
          ),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final ctrl = TextEditingController(text: _str(widget.vehicle['parkName']));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CustomIconWidget(
                  iconName: 'edit',
                  color: AppTheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Modifier le nom du parc',
                  style: GoogleFonts.ibmPlexSans(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkCharcoal,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Saisissez le nouveau nom du parc.',
                style: GoogleFonts.ibmPlexSans(fontSize: 13, color: AppTheme.mutedText),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: GoogleFonts.ibmPlexSans(fontSize: 15, color: AppTheme.darkCharcoal),
                decoration: InputDecoration(
                  hintText: 'Ex: Parc RTH â€” Hassi Messaoud',
                  hintStyle: GoogleFonts.ibmPlexSans(fontSize: 13, color: AppTheme.mutedText),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CustomIconWidget(iconName: 'local_parking', color: AppTheme.primary, size: 18),
                  ),
                  filled: true,
                  fillColor: AppTheme.backgroundLight,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.outlineVariantLight)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.outlineVariantLight)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isSavingPark ? null : () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.ibmPlexSans(color: AppTheme.mutedText)),
            ),
            ElevatedButton(
              onPressed: _isSavingPark
                  ? null
                  : () async {
                      final newName = ctrl.text.trim();
                      if (newName.isEmpty) return;
                      setDialogState(() => _isSavingPark = true);
                      try {
                        await SupabaseService.instance.updatePark(
                          parkId: parkId,
                          data: {'name': newName},
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          setState(() => widget.vehicle['parkName'] = newName);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(children: [
                                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Nom du parc mis Ã  jour', style: GoogleFonts.ibmPlexSans(fontSize: 13, color: Colors.white))),
                              ]),
                              backgroundColor: AppTheme.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => _isSavingPark = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.critical),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: _isSavingPark
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Enregistrer', style: GoogleFonts.ibmPlexSans(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insStart = _str(widget.vehicle['insuranceStart']);
    final insExpiry = _str(widget.vehicle['insuranceExpiry']);
    final inspExpiry = _str(widget.vehicle['inspectionExpiry']);
    final oilChange = _str(widget.vehicle['oilChange']);
    final generalRemark = _str(widget.vehicle['generalRemark']);
    final matricule = _str(widget.vehicle['matricule']);
    final type = _str(widget.vehicle['type']);
    final battery = _str(widget.vehicle['battery']);
    final wheelRef = _str(widget.vehicle['wheelRef']);
    final affectation = _str(widget.vehicle['affectation']);
    final parkName = _str(widget.vehicle['parkName']);

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
              _InfoRow(label: 'Matricule', value: matricule.isEmpty ? 'â€”' : matricule, isMonospace: true, isBold: true),
              const Divider(height: 1),
              _InfoRow(label: 'Type de vÃ©hicule', value: type.isEmpty ? 'SpÃ©cialisÃ©' : type),
              const Divider(height: 1),
              _InfoRow(label: 'Batterie', value: battery.isEmpty ? 'â€”' : battery),
              const Divider(height: 1),
              _InfoRow(label: 'RÃ©f. de roue', value: wheelRef.isEmpty ? 'â€”' : wheelRef, isMonospace: true),
              const Divider(height: 1),
              // Editable park name row
              _EditableInfoRow(
                label: 'Parc',
                value: parkName.isEmpty ? 'â€”' : parkName,
                canEdit: widget.canEdit,
                onEdit: _openEditParkName,
              ),
              const Divider(height: 1),
              _InfoRow(label: 'Affectation', value: affectation.isEmpty ? 'Non spÃ©cifiÃ©e' : affectation, isBold: true),
            ],
          ),

          const SizedBox(height: 12),

          // Administrative documents card
          _SectionCard(
            title: 'Documents administratifs',
            icon: 'description',
            children: [
              _DocumentRow(label: 'Assurance', startDate: _formatDate(insStart), endDate: _formatDate(insExpiry), isExpired: insuranceExpired, isExpiringSoon: !insuranceExpired && _isExpiringSoon(insExpiry)),
              const Divider(height: 1),
              _DocumentRow(label: 'ContrÃ´le technique', endDate: _formatDate(inspExpiry), isExpired: inspectionExpired, isExpiringSoon: !inspectionExpired && _isExpiringSoon(inspExpiry)),
              const Divider(height: 1),
              _DocumentRow(label: 'Vidange', endDate: _formatDate(oilChange), isExpired: false, isExpiringSoon: oilChangeSoon),
            ],
          ),

          const SizedBox(height: 12),

          if (hasRemark)
            _SectionCard(
              title: 'Remarque gÃ©nÃ©rale',
              icon: 'comment',
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: AppTheme.warningContainer, borderRadius: BorderRadius.circular(8)),
                        child: Center(child: CustomIconWidget(iconName: 'info', color: AppTheme.warning, size: 18)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(widget.vehicle['generalRemark'] as String, style: GoogleFonts.ibmPlexSans(fontSize: 13, color: AppTheme.darkCharcoal, height: 1.5))),
                    ],
                  ),
                ),
              ],
            ),

          if (!hasRemark)
            _SectionCard(
              title: 'Remarque gÃ©nÃ©rale',
              icon: 'comment',
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text('Aucune remarque enregistrÃ©e.', style: GoogleFonts.ibmPlexSans(fontSize: 13, color: AppTheme.mutedText, fontStyle: FontStyle.italic)),
                ),
              ],
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// â”€â”€ Section card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                CustomIconWidget(iconName: icon, color: AppTheme.primary, size: 16),
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

// â”€â”€ Plain info row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€ Editable info row (for park name) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EditableInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool canEdit;
  final VoidCallback onEdit;

  const _EditableInfoRow({
    required this.label,
    required this.value,
    required this.canEdit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppTheme.darkCharcoal,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          if (canEdit) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: CustomIconWidget(iconName: 'edit', color: AppTheme.primary, size: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// â”€â”€ Document row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
    if (isExpired) return 'EXPIRÃ‰';
    if (isExpiringSoon) return 'BIENTÃ”T';
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
                Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 13, color: AppTheme.mutedText)),
                const SizedBox(height: 3),
                if (startDate != null)
                  Text(
                    '$startDate â†’ $endDate',
                    style: GoogleFonts.ibmPlexMono(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.darkCharcoal),
                  )
                else
                  Text(
                    endDate,
                    style: GoogleFonts.ibmPlexMono(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.darkCharcoal),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(6)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomIconWidget(iconName: _statusIcon, color: _statusColor, size: 13),
                const SizedBox(width: 4),
                Text(
                  _statusText,
                  style: GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor, letterSpacing: 0.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
