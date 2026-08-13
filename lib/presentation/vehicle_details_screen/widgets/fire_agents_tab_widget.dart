import 'package:flutter/material.dart';

import '../../../../core/app_export.dart';
import '../../../../services/supabase_service.dart';

class FireAgentsTabWidget extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  final bool canEdit;

  const FireAgentsTabWidget({
    super.key,
    required this.vehicle,
    this.canEdit = true,
  });

  @override
  State<FireAgentsTabWidget> createState() => _FireAgentsTabWidgetState();
}

class _FireAgentsTabWidgetState extends State<FireAgentsTabWidget> {
  late Map<String, String> _values;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _values = {
      'water': widget.vehicle['water_capacity'] as String? ??
          widget.vehicle['water'] as String? ?? '—',
      'emulsifier': widget.vehicle['emulsifier_capacity'] as String? ??
          widget.vehicle['emulsifier'] as String? ?? '—',
      'powder': widget.vehicle['powder_capacity'] as String? ??
          widget.vehicle['powder'] as String? ?? '—',
      'cannonRange': widget.vehicle['cannon_range'] as String? ??
          widget.vehicle['cannonRange'] as String? ?? '—',
    };
  }

  @override
  void didUpdateWidget(covariant FireAgentsTabWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _values = {
      'water': widget.vehicle['water_capacity'] as String? ??
          widget.vehicle['water'] as String? ?? '—',
      'emulsifier': widget.vehicle['emulsifier_capacity'] as String? ??
          widget.vehicle['emulsifier'] as String? ?? '—',
      'powder': widget.vehicle['powder_capacity'] as String? ??
          widget.vehicle['powder'] as String? ?? '—',
      'cannonRange': widget.vehicle['cannon_range'] as String? ??
          widget.vehicle['cannonRange'] as String? ?? '—',
    };
  }

  String _getDbColumn(String key) {
    switch (key) {
      case 'water':
        return 'water_capacity';
      case 'emulsifier':
        return 'emulsifier_capacity';
      case 'powder':
        return 'powder_capacity';
      case 'cannonRange':
        return 'cannon_range';
      default:
        return key;
    }
  }

  void _openEditDialog(Map<String, dynamic> agent) {
    final key = agent['key'] as String;
    final ctrl = TextEditingController(
      text: _values[key] == '—' ? '' : _values[key],
    );

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
                  'Modifier — ${agent['label']}',
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                agent['description'] as String,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  color: AppTheme.mutedText,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 15,
                  color: AppTheme.darkCharcoal,
                ),
                decoration: InputDecoration(
                  hintText: 'Ex: 2000 L ou 40 m',
                  hintStyle: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    color: AppTheme.mutedText,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CustomIconWidget(
                      iconName: agent['icon'] as String,
                      color: agent['color'] as Color,
                      size: 18,
                    ),
                  ),
                  filled: true,
                  fillColor: AppTheme.backgroundLight,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppTheme.outlineVariantLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppTheme.outlineVariantLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppTheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : () => Navigator.pop(ctx),
              child: Text(
                'Annuler',
                style: GoogleFonts.ibmPlexSans(color: AppTheme.mutedText),
              ),
            ),
            ElevatedButton(
              onPressed: _isSaving
                  ? null
                  : () async {
                      final newVal =
                          ctrl.text.trim().isEmpty ? '—' : ctrl.text.trim();
                      final vehicleId = widget.vehicle['id'] as String?;
                      final dbColumn = _getDbColumn(key);

                      setDialogState(() => _isSaving = true);

                      if (vehicleId != null && vehicleId.isNotEmpty) {
                        try {
                          await SupabaseService.instance.updateVehicle(
                            vehicleId: vehicleId,
                            data: {dbColumn: newVal},
                          );
                        } catch (e) {
                          setDialogState(() => _isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur: $e'),
                                backgroundColor: AppTheme.critical,
                              ),
                            );
                          }
                          return;
                        }
                      }

                      setState(() {
                        _values[key] = newVal;
                        _isSaving = false;
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${agent['label']} mis à jour',
                                    style: GoogleFonts.ibmPlexSans(
                                      fontSize: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: AppTheme.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Enregistrer',
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    final agents = [
      {
        'key': 'water',
        'label': 'Eau',
        'value': _values['water']!,
        'icon': 'water_drop',
        'color': const Color(0xFF1E88E5),
        'bgColor': const Color(0xFFE3F2FD),
        'description': 'Capacité du réservoir d\'eau',
      },
      {
        'key': 'emulsifier',
        'label': 'Émulseur',
        'value': _values['emulsifier']!,
        'icon': 'science',
        'color': const Color(0xFF43A047),
        'bgColor': const Color(0xFFE8F5E9),
        'description': 'Capacité émulseur (mousse)',
      },
      {
        'key': 'powder',
        'label': 'Poudre',
        'value': _values['powder']!,
        'icon': 'grain',
        'color': const Color(0xFFF57C00),
        'bgColor': const Color(0xFFFFF3E0),
        'description': 'Charge de poudre extinctrice',
      },
      {
        'key': 'cannonRange',
        'label': 'Portée canon',
        'value': _values['cannonRange']!,
        'icon': 'gps_fixed',
        'color': const Color(0xFF8E24AA),
        'bgColor': const Color(0xFFF3E5F5),
        'description': 'Portée du canon à eau/mousse',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: CustomIconWidget(
                      iconName: 'local_fire_department',
                      color: AppTheme.primary,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Agents extincteurs / Débit pompe',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkCharcoal,
                  ),
                ),
              ],
            ),
          ),

          // Agent cards grid
          isTablet
              ? GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: agents.length,
                  itemBuilder: (ctx, i) => _AgentCard(
                    agent: agents[i],
                    onEdit: () => _openEditDialog(agents[i]),
                    canEdit: widget.canEdit,
                  ),
                )
              : Column(
                  children: agents
                      .map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AgentCard(
                            agent: a,
                            onEdit: () => _openEditDialog(a),
                            canEdit: widget.canEdit,
                          ),
                        ),
                      )
                      .toList(),
                ),

          const SizedBox(height: 16),

          // Info note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariantLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.outlineVariantLight),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomIconWidget(
                  iconName: 'info_outline',
                  color: AppTheme.mutedText,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Les valeurs sont renseignées selon la fiche technique du véhicule. '
                    'Toute modification doit être validée par le responsable du parc.',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      color: AppTheme.secondaryText,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  final Map<String, dynamic> agent;
  final VoidCallback onEdit;
  final bool canEdit;

  const _AgentCard({
    required this.agent,
    required this.onEdit,
    this.canEdit = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = agent['color'] as Color;
    final bgColor = agent['bgColor'] as Color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(51), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0D17202A),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: CustomIconWidget(
                iconName: agent['icon'] as String,
                color: color,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent['label'] as String,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mutedText,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  agent['value'] as String,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  agent['description'] as String,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    color: AppTheme.mutedText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (canEdit)
            IconButton(
              icon: CustomIconWidget(
                iconName: 'edit',
                color: AppTheme.mutedText,
                size: 18,
              ),
              onPressed: onEdit,
              tooltip: 'Modifier',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }
}
