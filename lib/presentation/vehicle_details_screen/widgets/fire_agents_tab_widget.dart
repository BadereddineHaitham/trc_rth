import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _initValues();
    _subscribeRealtime();
  }

  void _initValues() {
    _values = {
      // Agents extincteurs
      'water': widget.vehicle['water_capacity'] as String? ??
          widget.vehicle['water'] as String? ?? '—',
      'emulsifier': widget.vehicle['emulsifier_capacity'] as String? ??
          widget.vehicle['emulsifier'] as String? ?? '—',
      'powder': widget.vehicle['powder_capacity'] as String? ??
          widget.vehicle['powder'] as String? ?? '—',

      // Débit pompe
      'pumpFlowWater': widget.vehicle['pump_flow_water'] as String? ?? '—',
      'pumpFlowEmulsifier': widget.vehicle['pump_flow_emulsifier'] as String? ?? '—',
      'pumpFlowPowder': widget.vehicle['pump_flow_powder'] as String? ?? '—',
      'cannonRange': widget.vehicle['cannon_range'] as String? ??
          widget.vehicle['cannonRange'] as String? ?? '—',
    };
  }

  @override
  void didUpdateWidget(covariant FireAgentsTabWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initValues();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    final vehicleId = widget.vehicle['id'] as String?;
    if (vehicleId == null || vehicleId.isEmpty) return;

    _channel = SupabaseService.instance.client
        .channel('vehicle_agents_realtime_$vehicleId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vehicles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: vehicleId,
          ),
          callback: (payload) {
            final rec = payload.newRecord;
            if (rec.isNotEmpty && mounted) {
              setState(() {
                _values['water'] = rec['water_capacity'] as String? ?? '—';
                _values['emulsifier'] = rec['emulsifier_capacity'] as String? ?? '—';
                _values['powder'] = rec['powder_capacity'] as String? ?? '—';

                _values['pumpFlowWater'] = rec['pump_flow_water'] as String? ?? '—';
                _values['pumpFlowEmulsifier'] = rec['pump_flow_emulsifier'] as String? ?? '—';
                _values['pumpFlowPowder'] = rec['pump_flow_powder'] as String? ?? '—';
                _values['cannonRange'] = rec['cannon_range'] as String? ?? '—';
              });
            }
          },
        )
        .subscribe();
  }

  String _getDbColumn(String key) {
    switch (key) {
      case 'water':
        return 'water_capacity';
      case 'emulsifier':
        return 'emulsifier_capacity';
      case 'powder':
        return 'powder_capacity';
      case 'pumpFlowWater':
        return 'pump_flow_water';
      case 'pumpFlowEmulsifier':
        return 'pump_flow_emulsifier';
      case 'pumpFlowPowder':
        return 'pump_flow_powder';
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
    // Local flag — completely isolated per dialog, never pollutes other dialogs
    bool isSaving = false;

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
                  hintText: agent['hint'] as String? ?? 'Ex: 2000 L ou 1500 L/min',
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
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: Text(
                'Annuler',
                style: GoogleFonts.ibmPlexSans(color: AppTheme.mutedText),
              ),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final newVal =
                          ctrl.text.trim().isEmpty ? '—' : ctrl.text.trim();
                      final vehicleId = widget.vehicle['id'] as String?;
                      final dbColumn = _getDbColumn(key);

                      setDialogState(() => isSaving = true);

                      if (vehicleId != null && vehicleId.isNotEmpty) {
                        try {
                          await SupabaseService.instance.updateVehicle(
                            vehicleId: vehicleId,
                            data: {dbColumn: newVal},
                          );
                        } catch (e) {
                          setDialogState(() => isSaving = false);
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

                      if (mounted) setState(() => _values[key] = newVal);
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
              child: isSaving
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

    // ── 1. Agents extincteurs (Eau, Émulseur, Poudre) ──────────────────────────
    final extincteurAgents = [
      {
        'key': 'water',
        'label': 'Eau',
        'value': _values['water']!,
        'icon': 'water_drop',
        'color': const Color(0xFF1E88E5),
        'bgColor': const Color(0xFFE3F2FD),
        'description': 'Capacité du réservoir d\'eau',
        'hint': 'Ex: 3000 L',
      },
      {
        'key': 'emulsifier',
        'label': 'Émulseur',
        'value': _values['emulsifier']!,
        'icon': 'science',
        'color': const Color(0xFF43A047),
        'bgColor': const Color(0xFFE8F5E9),
        'description': 'Capacité émulseur (mousse)',
        'hint': 'Ex: 200 L',
      },
      {
        'key': 'powder',
        'label': 'Poudre',
        'value': _values['powder']!,
        'icon': 'grain',
        'color': const Color(0xFFF57C00),
        'bgColor': const Color(0xFFFFF3E0),
        'description': 'Charge de poudre extinctrice',
        'hint': 'Ex: 250 kg',
      },
    ];

    // ── 2. Débit pompe (Eau, Émulseur, Poudre, Portée canon) ───────────────────
    final debitPompeItems = [
      {
        'key': 'pumpFlowWater',
        'label': 'Débit Eau',
        'value': _values['pumpFlowWater']!,
        'icon': 'water_drop',
        'color': const Color(0xFF0288D1),
        'bgColor': const Color(0xFFE0F7FA),
        'description': 'Débit de la pompe à eau',
        'hint': 'Ex: 2000 L/min',
      },
      {
        'key': 'pumpFlowEmulsifier',
        'label': 'Débit Émulseur',
        'value': _values['pumpFlowEmulsifier']!,
        'icon': 'science',
        'color': const Color(0xFF2E7D32),
        'bgColor': const Color(0xFFE8F5E9),
        'description': 'Débit d\'injection émulseur',
        'hint': 'Ex: 150 L/min',
      },
      {
        'key': 'pumpFlowPowder',
        'label': 'Débit Poudre',
        'value': _values['pumpFlowPowder']!,
        'icon': 'grain',
        'color': const Color(0xFFE65100),
        'bgColor': const Color(0xFFFFF3E0),
        'description': 'Débit de projection de poudre',
        'hint': 'Ex: 35 kg/s',
      },
      {
        'key': 'cannonRange',
        'label': 'Portée canon',
        'value': _values['cannonRange']!,
        'icon': 'plumbing',
        'color': const Color(0xFF8E24AA),
        'bgColor': const Color(0xFFF3E5F5),
        'description': 'Portée du canon à eau/mousse',
        'hint': 'Ex: 40 m',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── SECTION 1: AGENTS EXTINCTEURS ───────────────────────────────────
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: CustomIconWidget(
                    iconName: 'local_fire_department',
                    color: Color(0xFFD32F2F),
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Agents extincteurs',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkCharcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGridOrList(extincteurAgents, isTablet),

          const SizedBox(height: 24),

          // ── SECTION 2: DÉBIT POMPE ──────────────────────────────────────────
          Row(
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
                    iconName: 'speed',
                    color: AppTheme.primary,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Débit pompe',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkCharcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGridOrList(debitPompeItems, isTablet),

          const SizedBox(height: 20),

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
                    'Les capacités des agents extincteurs et les débits de pompe sont mis à jour en temps réel. Toute modification est sauvegardée immédiatement.',
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

  Widget _buildGridOrList(List<Map<String, dynamic>> items, bool isTablet) {
    if (isTablet) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: items.length,
        itemBuilder: (ctx, i) => _AgentCard(
          agent: items[i],
          onEdit: () => _openEditDialog(items[i]),
          canEdit: widget.canEdit,
        ),
      );
    }

    return Column(
      children: items
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D17202A),
            blurRadius: 6,
            offset: Offset(0, 2),
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
                    fontSize: 22,
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
