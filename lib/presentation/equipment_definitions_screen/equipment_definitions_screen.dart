import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';

// ── Data Model ────────────────────────────────────────────────────────────────
class EquipmentDefinition {
  final String id;
  String name;
  String category;
  String unit;
  int defaultStandard;
  bool active;
  String? description;

  EquipmentDefinition({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.defaultStandard,
    this.active = true,
    this.description,
  });
}

// ── Seed Data ─────────────────────────────────────────────────────────────────
final List<EquipmentDefinition> _seedDefinitions = [
  EquipmentDefinition(
    id: 'eq-001',
    name: 'Tuyau Ø100',
    category: 'Tuyaux',
    unit: 'unité',
    defaultStandard: 10,
  ),
  EquipmentDefinition(
    id: 'eq-002',
    name: 'Tuyau Ø70',
    category: 'Tuyaux',
    unit: 'unité',
    defaultStandard: 8,
  ),
  EquipmentDefinition(
    id: 'eq-003',
    name: 'Tuyau Ø45',
    category: 'Tuyaux',
    unit: 'unité',
    defaultStandard: 6,
  ),
  EquipmentDefinition(
    id: 'eq-004',
    name: 'Lance à eau Ø45 LDV',
    category: 'Lances',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-005',
    name: 'Lance à eau Ø70',
    category: 'Lances',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-006',
    name: 'Lance à mousse Ø70',
    category: 'Lances',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-007',
    name: 'Lance à mousse Ø45',
    category: 'Lances',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-008',
    name: 'Réduction Ø100-70',
    category: 'Raccords',
    unit: 'unité',
    defaultStandard: 4,
  ),
  EquipmentDefinition(
    id: 'eq-009',
    name: 'Réduction Ø150-100',
    category: 'Raccords',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-010',
    name: 'Réduction Ø70-45',
    category: 'Raccords',
    unit: 'unité',
    defaultStandard: 4,
  ),
  EquipmentDefinition(
    id: 'eq-011',
    name: 'Division Ø100-70',
    category: 'Raccords',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-012',
    name: 'Division Ø70-45',
    category: 'Raccords',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-013',
    name: 'ARI',
    category: 'Protection',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-014',
    name: 'Tenue de pénétration',
    category: 'Protection',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-015',
    name: 'Tenue d\'approche',
    category: 'Protection',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-016',
    name: 'Masque',
    category: 'Protection',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-017',
    name: 'Gants',
    category: 'Protection',
    unit: 'paire',
    defaultStandard: 4,
  ),
  EquipmentDefinition(
    id: 'eq-018',
    name: 'Lunette',
    category: 'Protection',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-019',
    name: 'Extincteur',
    category: 'Extinction',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-020',
    name: 'Extincteur CO2',
    category: 'Extinction',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-021',
    name: 'Hache',
    category: 'Outils',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-022',
    name: 'Cisailles',
    category: 'Outils',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-023',
    name: 'Pelle',
    category: 'Outils',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-024',
    name: 'Pioche',
    category: 'Outils',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-025',
    name: 'Marteau',
    category: 'Outils',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-026',
    name: 'Arrache-clou',
    category: 'Outils',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-027',
    name: 'Clé F',
    category: 'Outils',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-028',
    name: 'Clé carrée',
    category: 'Outils',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-029',
    name: 'Perche',
    category: 'Outils',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-030',
    name: 'Tricoises',
    category: 'Outils',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-031',
    name: 'Crépine',
    category: 'Aspiration',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-032',
    name: 'Flotteur',
    category: 'Aspiration',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-033',
    name: 'Aspirants',
    category: 'Aspiration',
    unit: 'unité',
    defaultStandard: 4,
  ),
  EquipmentDefinition(
    id: 'eq-034',
    name: 'Aspirant 100',
    category: 'Aspiration',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-035',
    name: 'Pompe portatif',
    category: 'Aspiration',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-036',
    name: 'Échelle',
    category: 'Accès',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-037',
    name: 'Échelle en aluminium',
    category: 'Accès',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-038',
    name: 'Collecteur',
    category: 'Raccords',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-039',
    name: 'Lance monitor',
    category: 'Lances',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-040',
    name: 'Projecteur',
    category: 'Éclairage',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-041',
    name: 'Rallonge électrique',
    category: 'Éclairage',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-042',
    name: 'Couverture anti-feu',
    category: 'Protection',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-043',
    name: 'Boîte pharmacie',
    category: 'Secours',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-044',
    name: 'Triangle de panne',
    category: 'Sécurité',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-045',
    name: 'Gonfleur',
    category: 'Sécurité',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-046',
    name: 'Tuyau de gonflage',
    category: 'Sécurité',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-047',
    name: 'Capa matériel',
    category: 'Protection',
    unit: 'unité',
    defaultStandard: 1,
  ),
  EquipmentDefinition(
    id: 'eq-048',
    name: 'Capa du tenu d\'approche',
    category: 'Protection',
    unit: 'unité',
    defaultStandard: 2,
  ),
  EquipmentDefinition(
    id: 'eq-049',
    name: 'Rallonge',
    category: 'Éclairage',
    unit: 'unité',
    defaultStandard: 1,
  ),
];

const List<String> _categories = [
  'Tuyaux',
  'Lances',
  'Raccords',
  'Protection',
  'Extinction',
  'Outils',
  'Aspiration',
  'Accès',
  'Éclairage',
  'Secours',
  'Sécurité',
  'Autre',
];

const List<String> _units = [
  'unité',
  'paire',
  'kg',
  'litre',
  'm',
  'm²',
  'rouleau',
  'boîte',
  'set',
];

// ── Screen ────────────────────────────────────────────────────────────────────
class EquipmentDefinitionsScreen extends StatefulWidget {
  const EquipmentDefinitionsScreen({super.key});

  @override
  State<EquipmentDefinitionsScreen> createState() =>
      _EquipmentDefinitionsScreenState();
}

class _EquipmentDefinitionsScreenState
    extends State<EquipmentDefinitionsScreen> {
  final List<EquipmentDefinition> _definitions = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterCategory;
  bool _showInactive = false;
  bool _isLoading = true;
  String? _errorMsg;
  final _svc = SupabaseService.instance;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadDefinitions();
    _subscribeRealtime();
  }

  Future<void> _loadDefinitions() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final data = await _svc.getEquipmentDefinitions();
      if (mounted) {
        setState(() {
          _definitions.clear();
          _definitions.addAll(
            data.map(
              (m) => EquipmentDefinition(
                id: m['id'] as String? ?? '',
                name: m['name'] as String? ?? '',
                category: m['category'] as String? ?? '',
                unit: m['unit'] as String? ?? 'unité',
                defaultStandard: (m['default_standard'] as int?) ?? 1,
                active: m['active'] as bool? ?? true,
                description: m['description'] as String?,
              ),
            ),
          );
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
        .channel('equipment_definitions_screen')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'equipment_definitions',
          callback: (_) => _loadDefinitions(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  List<EquipmentDefinition> get _filtered {
    return _definitions.where((d) {
      final matchSearch =
          _searchQuery.isEmpty ||
          d.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchCategory =
          _filterCategory == null || d.category == _filterCategory;
      final matchActive = _showInactive ? true : d.active;
      return matchSearch && matchCategory && matchActive;
    }).toList()..sort((a, b) {
      if (a.active && !b.active) return -1;
      if (!a.active && b.active) return 1;
      return a.category.compareTo(b.category);
    });
  }

  Map<String, List<EquipmentDefinition>> get _grouped {
    final result = <String, List<EquipmentDefinition>>{};
    for (final d in _filtered) {
      result.putIfAbsent(d.category, () => []).add(d);
    }
    return result;
  }

  int get _activeCount => _definitions.where((d) => d.active).length;
  int get _inactiveCount => _definitions.where((d) => !d.active).length;

  void _showAddEditDialog({EquipmentDefinition? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final standardCtrl = TextEditingController(
      text: existing?.defaultStandard.toString() ?? '1',
    );
    String selectedCategory = existing?.category ?? _categories.first;
    String selectedUnit = existing?.unit ?? _units.first;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.outlineLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: CustomIconWidget(
                            iconName: isEdit ? 'edit' : 'add',
                            color: AppTheme.primary,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEdit
                              ? 'Modifier l\'équipement'
                              : 'Nouvel équipement',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkCharcoal,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: CustomIconWidget(
                          iconName: 'close',
                          color: AppTheme.secondaryText,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.outlineVariantLight),
                // Form
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name
                          _formLabel('Désignation *'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Ex: Tuyau Ø100',
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'La désignation est obligatoire'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          // Category
                          _formLabel('Catégorie *'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            decoration: const InputDecoration(),
                            items: _categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c,
                                      style: GoogleFonts.ibmPlexSans(
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setModalState(() => selectedCategory = v);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          // Unit + Standard row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _formLabel('Unité *'),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      initialValue: selectedUnit,
                                      decoration: const InputDecoration(),
                                      items: _units
                                          .map(
                                            (u) => DropdownMenuItem(
                                              value: u,
                                              child: Text(
                                                u,
                                                style: GoogleFonts.ibmPlexSans(
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          setModalState(() => selectedUnit = v);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _formLabel('Standard par défaut *'),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: standardCtrl,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: const InputDecoration(
                                        hintText: '1',
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Obligatoire';
                                        }
                                        final n = int.tryParse(v);
                                        if (n == null || n < 0) {
                                          return 'Valeur invalide';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Description
                          _formLabel('Description (optionnel)'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: descCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'Remarque ou description...',
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Actions
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(
                                    'Annuler',
                                    style: GoogleFonts.ibmPlexSans(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (formKey.currentState!.validate()) {
                                      final std =
                                          int.tryParse(standardCtrl.text) ?? 1;
                                      Navigator.pop(ctx);
                                      try {
                                        if (isEdit) {
                                          await _svc.updateEquipmentDefinition(
                                            id: existing.id,
                                            data: {
                                              'name': nameCtrl.text.trim(),
                                              'category': selectedCategory,
                                              'unit': selectedUnit,
                                              'default_standard': std,
                                              'description':
                                                  descCtrl.text.trim().isEmpty
                                                  ? ''
                                                  : descCtrl.text.trim(),
                                            },
                                          );
                                        } else {
                                          await _svc.createEquipmentDefinition(
                                            name: nameCtrl.text.trim(),
                                            category: selectedCategory,
                                            unit: selectedUnit,
                                            defaultStandard: std,
                                            description: descCtrl.text.trim(),
                                          );
                                        }
                                        _showSnackbar(
                                          isEdit
                                              ? 'Équipement modifié avec succès.'
                                              : 'Équipement ajouté avec succès.',
                                          AppTheme.success,
                                        );
                                      } catch (e) {
                                        _showSnackbar(
                                          'Erreur: $e',
                                          AppTheme.critical,
                                        );
                                      }
                                    }
                                  },
                                  child: Text(
                                    isEdit ? 'Enregistrer' : 'Ajouter',
                                    style: GoogleFonts.ibmPlexSans(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleActive(EquipmentDefinition def) {
    final action = def.active ? 'désactiver' : 'réactiver';
    final actionLabel = def.active ? 'Désactiver' : 'Réactiver';
    final color = def.active ? AppTheme.critical : AppTheme.success;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          '$actionLabel l\'équipement ?',
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.w700,
            color: AppTheme.darkCharcoal,
            fontSize: 16,
          ),
        ),
        content: Text(
          def.active
              ? 'L\'équipement "${def.name}" sera désactivé et n\'apparaîtra plus dans les nouvelles configurations de véhicules. L\'historique existant sera conservé.'
              : 'L\'équipement "${def.name}" sera réactivé et disponible pour les configurations de véhicules.',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            color: AppTheme.secondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Annuler',
              style: GoogleFonts.ibmPlexSans(color: AppTheme.mutedText),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _svc.updateEquipmentDefinition(
                  id: def.id,
                  data: {'active': !def.active},
                );
                _showSnackbar(
                  def.active ? 'Équipement désactivé.' : 'Équipement réactivé.',
                  def.active ? AppTheme.warning : AppTheme.success,
                );
              } catch (e) {
                _showSnackbar('Erreur: $e', AppTheme.critical);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: Text(
              actionLabel,
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _formLabel(String text) => Text(
    text,
    style: GoogleFonts.ibmPlexSans(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppTheme.secondaryText,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    final categories = grouped.keys.toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.darkCharcoal,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: CustomIconWidget(
            iconName: 'arrow_back',
            color: Colors.white,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Définitions équipements',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              'Super Admin — Configuration',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 11,
                color: Colors.white.withAlpha(153),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: CustomIconWidget(
              iconName: _showInactive ? 'visibility' : 'visibility_off',
              color: _showInactive
                  ? AppTheme.primary
                  : Colors.white.withAlpha(153),
              size: 22,
            ),
            tooltip: _showInactive
                ? 'Masquer les inactifs'
                : 'Afficher les inactifs',
            onPressed: () => setState(() => _showInactive = !_showInactive),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomIconWidget(
                    iconName: 'error_outline',
                    color: AppTheme.critical,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Erreur: $_errorMsg',
                    style: GoogleFonts.ibmPlexSans(color: AppTheme.mutedText),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadDefinitions,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Stats strip
                Container(
                  color: AppTheme.darkCharcoal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Row(
                    children: [
                      _statChip('$_activeCount', 'Actifs', AppTheme.success),
                      const SizedBox(width: 8),
                      _statChip(
                        '$_inactiveCount',
                        'Inactifs',
                        AppTheme.mutedText,
                      ),
                      const SizedBox(width: 8),
                      _statChip(
                        '${_definitions.length}',
                        'Total',
                        AppTheme.primary,
                      ),
                    ],
                  ),
                ),
                // Search + filter bar
                Container(
                  color: AppTheme.surfaceLight,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Rechercher un équipement...',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: CustomIconWidget(
                              iconName: 'search',
                              color: AppTheme.mutedText,
                              size: 20,
                            ),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: CustomIconWidget(
                                    iconName: 'clear',
                                    color: AppTheme.mutedText,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Category filter chips
                      SizedBox(
                        height: 32,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _filterChip('Toutes', null),
                            ..._categories.map((c) => _filterChip(c, c)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.outlineVariantLight),
                // List
                Expanded(
                  child: _filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 100),
                          itemCount: categories.length,
                          itemBuilder: (ctx, i) {
                            final cat = categories[i];
                            final items = grouped[cat]!;
                            return _buildCategorySection(cat, items);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppTheme.primary,
        icon: CustomIconWidget(iconName: 'add', color: Colors.white, size: 20),
        label: Text(
          'Ajouter équipement',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 11,
              color: color.withAlpha(204),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final isSelected = _filterCategory == value;
    return GestureDetector(
      onTap: () => setState(() => _filterCategory = value),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceVariantLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.outlineVariantLight,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : AppTheme.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    String category,
    List<EquipmentDefinition> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                category,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondaryText,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariantLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${items.length}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mutedText,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...items.map((def) => _buildDefinitionCard(def)),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildDefinitionCard(EquipmentDefinition def) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: def.active
            ? AppTheme.surfaceLight
            : AppTheme.surfaceVariantLight.withAlpha(128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: def.active
              ? AppTheme.outlineVariantLight
              : AppTheme.outlineLight.withAlpha(128),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Status dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: def.active ? AppTheme.success : AppTheme.mutedText,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          def.name,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: def.active
                                ? AppTheme.darkCharcoal
                                : AppTheme.mutedText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!def.active)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.outlineLight.withAlpha(77),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'INACTIF',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.mutedText,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _infoTag(def.unit, 'inventory_2'),
                      const SizedBox(width: 8),
                      _infoTag('Std: ${def.defaultStandard}', 'straighten'),
                    ],
                  ),
                  if (def.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      def.description!,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 11,
                        color: AppTheme.mutedText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Edit
                _actionButton(
                  icon: 'edit',
                  color: AppTheme.primary,
                  bgColor: AppTheme.primaryContainer,
                  onTap: () => _showAddEditDialog(existing: def),
                  tooltip: 'Modifier',
                ),
                const SizedBox(width: 6),
                // Toggle active
                _actionButton(
                  icon: def.active ? 'toggle_on' : 'toggle_off',
                  color: def.active ? AppTheme.critical : AppTheme.success,
                  bgColor: def.active
                      ? AppTheme.criticalContainer
                      : AppTheme.successContainer,
                  onTap: () => _toggleActive(def),
                  tooltip: def.active ? 'Désactiver' : 'Réactiver',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTag(String text, String icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomIconWidget(iconName: icon, color: AppTheme.mutedText, size: 12),
        const SizedBox(width: 3),
        Text(
          text,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 11,
            color: AppTheme.mutedText,
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: CustomIconWidget(iconName: icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomIconWidget(
              iconName: 'inventory_2',
              color: AppTheme.mutedText,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun équipement trouvé',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Modifiez vos filtres ou ajoutez un nouvel équipement.',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                color: AppTheme.mutedText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
