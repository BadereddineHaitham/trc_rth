import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/app_export.dart';
import '../../../../services/supabase_service.dart';

enum UserRole { superAdmin, admin, user }

class EquipmentTabWidget extends StatefulWidget {
  final String vehicleId;
  final String vehicleName;
  final UserRole userRole;

  const EquipmentTabWidget({
    super.key,
    required this.vehicleId,
    this.vehicleName = '',
    this.userRole = UserRole.admin,
  });

  @override
  State<EquipmentTabWidget> createState() => _EquipmentTabWidgetState();
}

class _EquipmentTabWidgetState extends State<EquipmentTabWidget> {
  final _svc = SupabaseService.instance;
  List<Map<String, dynamic>> _equipmentData = [];
  bool _isLoading = true;
  String? _errorMsg;
  RealtimeChannel? _channel;

  bool get _canEdit =>
      widget.userRole == UserRole.admin ||
      widget.userRole == UserRole.superAdmin;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final records = await _svc.getVehicleEquipment(widget.vehicleId);
      if (mounted) {
        setState(() {
          _equipmentData = records.map((r) {
            final def =
                r['equipment_definitions'] as Map<String, dynamic>? ?? {};
            return {
              'id': r['id'] as String? ?? '',
              'defId': (r['equipment_definition_id'] as String?) ??
                  (def['id'] as String?) ??
                  '',
              'designation': def['name'] as String? ?? 'Équipement',
              'category': def['category'] as String? ?? 'Équipement incendie',
              'unit': def['unit'] as String? ?? 'unité',
              'standard': (r['standard_quantity'] as int?) ?? 0,
              'existing': (r['existing_quantity'] as int?) ?? 0,
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _subscribeRealtime() {
    _channel = _svc.client
        .channel('equip_${widget.vehicleId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vehicle_equipment',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'vehicle_id',
            value: widget.vehicleId,
          ),
          callback: (_) => _loadData(),
        )
        .subscribe();
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final Map<String, List<Map<String, dynamic>>> result = {};
    for (final item in _equipmentData) {
      final cat = item['category'] as String? ?? 'Autre';
      result.putIfAbsent(cat, () => []).add(item);
    }
    return result;
  }

  int get _totalMissing => _equipmentData.fold(0, (sum, e) {
        final std = (e['standard'] as int?) ?? 0;
        final exist = (e['existing'] as int?) ?? 0;
        return sum + (std > exist ? std - exist : 0);
      });

  void _showAddEquipmentModal() {
    final nameCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'Équipement incendie');
    final standardCtrl = TextEditingController(text: '1');
    final existingCtrl = TextEditingController(text: '1');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Ajouter un équipement',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkCharcoal,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Désignation *',
                hintText: 'ex: Lance 70/28, Tuyau 45mm...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryCtrl,
              decoration: const InputDecoration(
                labelText: 'Catégorie',
                hintText: 'ex: Tuyaux, Lances, Accessoires',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: standardCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Standard'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: existingCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Existant'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final std = int.tryParse(standardCtrl.text.trim()) ?? 1;
                  final exist = int.tryParse(existingCtrl.text.trim()) ?? 1;

                  Navigator.pop(ctx);
                  try {
                    await _svc.addVehicleEquipmentItem(
                      vehicleId: widget.vehicleId,
                      designation: name,
                      category: categoryCtrl.text.trim(),
                      standardQuantity: std,
                      existingQuantity: exist,
                    );
                    await _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Équipement "$name" ajouté',
                            style: GoogleFonts.ibmPlexSans(color: Colors.white),
                          ),
                          backgroundColor: AppTheme.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur: $e'),
                          backgroundColor: AppTheme.critical,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditEquipmentModal(Map<String, dynamic> item) {
    final nameCtrl = TextEditingController(text: item['designation'] as String? ?? '');
    final standardCtrl = TextEditingController(text: '${item['standard'] ?? 0}');
    final existingCtrl = TextEditingController(text: '${item['existing'] ?? 0}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Modifier l\'équipement',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkCharcoal,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Désignation *'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: standardCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Standard'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: existingCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Existant'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final std = int.tryParse(standardCtrl.text.trim()) ?? 0;
                  final exist = int.tryParse(existingCtrl.text.trim()) ?? 0;

                  Navigator.pop(ctx);
                  try {
                    await _svc.updateVehicleEquipmentItem(
                      vehicleEquipmentId: item['id'] as String,
                      equipmentDefinitionId: item['defId'] as String? ?? '',
                      designation: name,
                      standardQuantity: std,
                      existingQuantity: exist,
                    );
                    await _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('"$name" mis à jour'),
                          backgroundColor: AppTheme.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur: $e'),
                          backgroundColor: AppTheme.critical,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEquipment(Map<String, dynamic> item) async {
    final id = item['id'] as String?;
    final designation = item['designation'] as String? ?? 'l\'équipement';
    if (id == null || id.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'équipement'),
        content: Text('Retirer "$designation" de ce véhicule ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _svc.deleteVehicleEquipmentItem(id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$designation" supprimé'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.critical,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMsg != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'error_outline',
              color: AppTheme.critical,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Erreur: $_errorMsg',
              style: GoogleFonts.ibmPlexSans(color: AppTheme.mutedText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    final grouped = _grouped;
    final missing = _totalMissing;

    return Column(
      children: [
        // Summary header
        Container(
          color: AppTheme.surfaceLight,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Armement du véhicule',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkCharcoal,
                      ),
                    ),
                    Text(
                      '${_equipmentData.length} équipements • $missing manquant(s)',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        color: missing > 0
                            ? AppTheme.critical
                            : AppTheme.success,
                      ),
                    ),
                  ],
                ),
              ),
              if (_canEdit)
                ElevatedButton.icon(
                  onPressed: _showAddEquipmentModal,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    textStyle: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(height: 1, color: AppTheme.outlineVariantLight),
        Expanded(
          child: _equipmentData.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Aucun équipement enregistré',
                        style: GoogleFonts.ibmPlexSans(color: AppTheme.mutedText),
                      ),
                      if (_canEdit) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _showAddEquipmentModal,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Ajouter un équipement'),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: grouped.entries.map((entry) {
                    return _CategorySection(
                      category: entry.key,
                      items: entry.value,
                      canEdit: _canEdit,
                      onEdit: (item) => _showEditEquipmentModal(item),
                      onDelete: (item) => _deleteEquipment(item),
                      onQuantityChanged: (itemId, newQty) async {
                        try {
                          await _svc.updateEquipmentQuantity(
                            vehicleEquipmentId: itemId,
                            existingQuantity: newQty,
                            vehicleId: widget.vehicleId,
                            vehicleName: widget.vehicleName,
                          );
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur: $e'),
                                backgroundColor: AppTheme.critical,
                              ),
                            );
                          }
                        }
                      },
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final List<Map<String, dynamic>> items;
  final bool canEdit;
  final Function(Map<String, dynamic> item) onEdit;
  final Function(Map<String, dynamic> item) onDelete;
  final Function(String id, int qty) onQuantityChanged;

  const _CategorySection({
    required this.category,
    required this.items,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            category,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
        ),
        ...items.map(
          (item) => _EquipmentRow(
            item: item,
            canEdit: canEdit,
            onEdit: () => onEdit(item),
            onDelete: () => onDelete(item),
            onQuantityChanged: onQuantityChanged,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _EquipmentRow extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(String id, int qty) onQuantityChanged;

  const _EquipmentRow({
    required this.item,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
    required this.onQuantityChanged,
  });

  @override
  State<_EquipmentRow> createState() => _EquipmentRowState();
}

class _EquipmentRowState extends State<_EquipmentRow> {
  late int _existing;

  @override
  void initState() {
    super.initState();
    _existing = (widget.item['existing'] as int?) ?? 0;
  }

  @override
  void didUpdateWidget(_EquipmentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _existing = (widget.item['existing'] as int?) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final standard = (widget.item['standard'] as int?) ?? 0;
    final missing = standard > _existing ? standard - _existing : 0;
    final isMissing = missing > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isMissing
            ? AppTheme.criticalContainer.withAlpha(80)
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMissing
              ? AppTheme.critical.withAlpha(60)
              : AppTheme.outlineVariantLight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item['designation'] as String? ?? '',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkCharcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Standard: $standard ${widget.item['unit'] ?? ''}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    color: AppTheme.mutedText,
                  ),
                ),
              ],
            ),
          ),
          if (widget.canEdit) ...[
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              color: _existing > 0 ? AppTheme.critical : Colors.grey,
              onPressed: _existing > 0
                  ? () {
                      setState(() => _existing--);
                      widget.onQuantityChanged(
                        widget.item['id'] as String,
                        _existing,
                      );
                    }
                  : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
          Container(
            width: 32,
            alignment: Alignment.center,
            child: Text(
              '$_existing',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isMissing ? AppTheme.critical : AppTheme.success,
              ),
            ),
          ),
          if (widget.canEdit) ...[
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              color: AppTheme.success,
              onPressed: () {
                setState(() => _existing++);
                widget.onQuantityChanged(
                  widget.item['id'] as String,
                  _existing,
                );
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppTheme.primary,
              onPressed: widget.onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Modifier',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppTheme.critical,
              onPressed: widget.onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Supprimer',
            ),
          ],
          if (isMissing)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.critical,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '-$missing',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
