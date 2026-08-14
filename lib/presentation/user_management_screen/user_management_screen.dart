import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_icon_widget.dart';
import '../../services/supabase_service.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------
class _UserModel {
  final String id;
  String username;
  String fullName;
  String email;
  String role;
  bool isActive;
  DateTime lastActivity;
  DateTime createdAt;

  _UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.lastActivity,
    required this.createdAt,
  });

  factory _UserModel.fromSupabase(Map<String, dynamic> data) {
    final meta = (data['user_metadata'] as Map?)?.cast<String, dynamic>() ?? {};
    final email = data['email'] as String? ?? '';
    final username = meta['username'] as String? ?? email.split('@').first;
    final fullName = meta['full_name'] as String? ?? username;
    final role = meta['role'] as String? ?? 'User';
    final bannedUntil = data['banned_until'] as String?;
    final isActive = bannedUntil == null || bannedUntil.isEmpty;
    final lastSignIn = data['last_sign_in_at'] as String?;
    final createdAt = data['created_at'] as String?;

    return _UserModel(
      id: data['id'] as String? ?? '',
      username: username,
      fullName: fullName,
      email: email,
      role: role,
      isActive: isActive,
      lastActivity: lastSignIn != null
          ? DateTime.tryParse(lastSignIn) ?? DateTime.now()
          : DateTime.now(),
      createdAt: createdAt != null
          ? DateTime.tryParse(createdAt) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterRole = 'Tous';
  String _searchQuery = '';
  bool _isLoading = true;
  String? _loadError;

  final List<_UserModel> _users = [];
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    // Subscribe to auth schema changes via audit_logs as a proxy for user changes
    _realtimeChannel = SupabaseService.instance.client
        .channel('user_management_audit')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'audit_logs',
          callback: (payload) {
            final action = payload.newRecord['action'] as String? ?? '';
            if (action.startsWith('user_')) {
              _loadUsers();
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final raw = await SupabaseService.instance.listUsers();
      final models = raw.map((u) => _UserModel.fromSupabase(u)).toList();
      models.sort((a, b) {
        const order = {'Super Admin': 0, 'Admin': 1, 'User': 2};
        return (order[a.role] ?? 3).compareTo(order[b.role] ?? 3);
      });
      if (mounted) {
        setState(() {
          _users
            ..clear()
            ..addAll(models);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<_UserModel> get _filteredUsers {
    return _users.where((u) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          u.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.email.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRole = _filterRole == 'Tous' || u.role == _filterRole;
      return matchesSearch && matchesRole;
    }).toList();
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------
  Color _roleColor(String role) {
    switch (role) {
      case 'Super Admin':
        return const Color(0xFF1A237E);
      case 'Admin':
        return AppTheme.primary;
      default:
        return AppTheme.secondaryText;
    }
  }

  Color _roleBgColor(String role) {
    switch (role) {
      case 'Super Admin':
        return const Color(0xFF1A237E).withAlpha(20);
      case 'Admin':
        return AppTheme.primary.withAlpha(20);
      default:
        return AppTheme.secondaryText.withAlpha(20);
    }
  }

  String _roleIcon(String role) {
    switch (role) {
      case 'Super Admin':
        return 'admin_panel_settings';
      case 'Admin':
        return 'manage_accounts';
      default:
        return 'person';
    }
  }

  String _formatLastActivity(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 30) return 'Il y a ${diff.inDays} j';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------
  void _toggleAccount(_UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          user.isActive ? 'Désactiver le compte' : 'Activer le compte',
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.w700,
            color: AppTheme.darkCharcoal,
            fontSize: 16,
          ),
        ),
        content: Text(
          user.isActive
              ? 'Désactiver le compte de ${user.fullName} ? L\'utilisateur ne pourra plus se connecter.'
              : 'Réactiver le compte de ${user.fullName} ?',
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
          _ConfirmButton(
            label: user.isActive ? 'Désactiver' : 'Activer',
            color: user.isActive ? AppTheme.critical : AppTheme.success,
            onConfirm: () async {
              await SupabaseService.instance.setUserBanned(
                userId: user.id,
                banned: user.isActive,
              );
              setState(() => user.isActive = !user.isActive);
            },
            onSuccess: () {
              _showSnackbar(
                user.isActive
                    ? 'Compte activé avec succès.'
                    : 'Compte désactivé.',
                user.isActive ? AppTheme.success : AppTheme.warning,
              );
            },
            onError: (e) => _showSnackbar(e, AppTheme.critical),
          ),
        ],
      ),
    );
  }

  void _deleteUser(_UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Supprimer le compte',
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.w700,
            color: AppTheme.critical,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Supprimer définitivement le compte de ${user.fullName} (${user.email}) ?',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                color: AppTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.criticalContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.critical.withAlpha(80)),
              ),
              child: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'warning',
                    color: AppTheme.critical,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cette action est irréversible.',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        color: AppTheme.critical,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Annuler',
              style: GoogleFonts.ibmPlexSans(color: AppTheme.mutedText),
            ),
          ),
          _ConfirmButton(
            label: 'Supprimer',
            color: AppTheme.critical,
            onConfirm: () async {
              await SupabaseService.instance.deleteUser(user.id);
              setState(() => _users.removeWhere((u) => u.id == user.id));
            },
            onSuccess: () {
              _showSnackbar('Compte supprimé.', AppTheme.critical);
            },
            onError: (e) => _showSnackbar(e, AppTheme.critical),
          ),
        ],
      ),
    );
  }

  void _resetPassword(_UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Réinitialiser le mot de passe',
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.w700,
            color: AppTheme.darkCharcoal,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Réinitialiser le mot de passe de ${user.fullName} (${user.username}) ?',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                color: AppTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withAlpha(80)),
              ),
              child: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'info_outline',
                    color: AppTheme.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Un email de réinitialisation sera envoyé à ${user.email}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        color: AppTheme.darkCharcoal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Annuler',
              style: GoogleFonts.ibmPlexSans(color: AppTheme.mutedText),
            ),
          ),
          _ConfirmButton(
            label: 'Envoyer',
            color: AppTheme.primary,
            onConfirm: () async {
              await SupabaseService.instance.sendPasswordResetEmail(user.email);
            },
            onSuccess: () {
              _showSnackbar(
                'Email de réinitialisation envoyé à ${user.email}',
                AppTheme.success,
              );
            },
            onError: (e) => _showSnackbar(e, AppTheme.critical),
          ),
        ],
      ),
    );
  }

  void _showAddUserSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddUserSheet(
        onAdd: (user) {
          setState(() {
            _users.add(user);
            _users.sort((a, b) {
              const order = {'Super Admin': 0, 'Admin': 1, 'User': 2};
              return (order[a.role] ?? 3).compareTo(order[b.role] ?? 3);
            });
          });
          _showSnackbar(
            'Compte ${user.username} créé avec succès.',
            AppTheme.success,
          );
        },
      ),
    );
  }

  void _editUser(_UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditUserSheet(
        user: user,
        onSave: (fullName, email, role) {
          setState(() {
            user.fullName = fullName;
            user.email = email;
            user.role = role;
          });
          _showSnackbar(
            'Compte ${user.username} modifié avec succès.',
            AppTheme.success,
          );
        },
      ),
    );
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;
    final totalActive = _users.where((u) => u.isActive).length;
    final totalInactive = _users.where((u) => !u.isActive).length;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Gestion des utilisateurs',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: CustomIconWidget(
              iconName: 'refresh',
              color: Colors.white,
              size: 22,
            ),
            onPressed: _loadUsers,
            tooltip: 'Actualiser',
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withAlpha(60)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF69F0AE),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'LIVE',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _buildErrorState()
          : Column(
              children: [
                _buildStatsStrip(totalActive, totalInactive),
                _buildSearchAndFilter(),
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) => _buildUserCard(filtered[i]),
                        ),
                ),
              ],
            ),
      floatingActionButton: _isLoading || _loadError != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddUserSheet,
              backgroundColor: const Color(0xFF1A237E),
              icon: CustomIconWidget(
                iconName: 'person_add',
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                'Ajouter un compte',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'error_outline',
              color: AppTheme.critical,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              'Impossible de charger les utilisateurs',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkCharcoal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _loadError ?? '',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                color: AppTheme.mutedText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomIconWidget(
            iconName: 'people_outline',
            color: AppTheme.mutedText,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun utilisateur trouvé',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkCharcoal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Aucun résultat pour "$_searchQuery"'
                : 'Aucun utilisateur dans cette catégorie',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              color: AppTheme.mutedText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsStrip(int active, int inactive) {
    final adminCount = _users.where((u) => u.role == 'Admin').length;

    return Container(
      color: const Color(0xFF1A237E),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: _buildStatChip(
              '${_users.length}',
              'Total',
              'people',
              Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatChip(
              '$active',
              'Actifs',
              'check_circle',
              const Color(0xFF69F0AE),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatChip(
              '$inactive',
              'Inactifs',
              'block',
              const Color(0xFFFF5252),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatChip(
              '$adminCount',
              'Admins',
              'manage_accounts',
              const Color(0xFF82B1FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String value, String label, String icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomIconWidget(iconName: icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            value,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 10,
                color: Colors.white.withAlpha(180),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Rechercher par nom, email...',
              hintStyle: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                color: AppTheme.mutedText,
              ),
              prefixIcon: CustomIconWidget(
                iconName: 'search',
                color: AppTheme.mutedText,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: CustomIconWidget(
                        iconName: 'close',
                        color: AppTheme.mutedText,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.backgroundLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Role filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Tous', 'Super Admin', 'Admin', 'User'].map((role) {
                final isSelected = _filterRole == role;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      role,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.darkCharcoal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _filterRole = role),
                    selectedColor: const Color(0xFF1A237E),
                    backgroundColor: AppTheme.backgroundLight,
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF1A237E)
                          : AppTheme.outlineVariantLight,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 0,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(_UserModel user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: user.isActive
              ? AppTheme.outlineVariantLight
              : AppTheme.critical.withAlpha(60),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            decoration: BoxDecoration(
              color: _roleBgColor(user.role),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _roleColor(user.role).withAlpha(30),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _roleColor(user.role).withAlpha(80),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      user.fullName.isNotEmpty
                          ? user.fullName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _roleColor(user.role),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.fullName,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkCharcoal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Role badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _roleColor(user.role).withAlpha(20),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: _roleColor(user.role).withAlpha(60),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CustomIconWidget(
                                  iconName: _roleIcon(user.role),
                                  color: _roleColor(user.role),
                                  size: 11,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  user.role,
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _roleColor(user.role),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${user.username}',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 11,
                          color: AppTheme.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status toggle
                GestureDetector(
                  onTap: user.role == 'Super Admin'
                      ? null
                      : () => _toggleAccount(user),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: user.isActive
                          ? AppTheme.successContainer
                          : AppTheme.criticalContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: user.isActive
                            ? AppTheme.success.withAlpha(80)
                            : AppTheme.critical.withAlpha(80),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: user.isActive
                                ? AppTheme.success
                                : AppTheme.critical,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.isActive ? 'Actif' : 'Inactif',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: user.isActive
                                ? AppTheme.success
                                : AppTheme.critical,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Info row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'email',
                      color: AppTheme.mutedText,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        user.email,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 12,
                          color: AppTheme.secondaryText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CustomIconWidget(
                      iconName: 'access_time',
                      color: AppTheme.mutedText,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatLastActivity(user.lastActivity),
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 11,
                        color: AppTheme.mutedText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Action buttons
                if (user.role != 'Super Admin')
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _ActionBtn(
                        icon: 'edit',
                        label: 'Modifier',
                        color: AppTheme.primary,
                        onTap: () => _editUser(user),
                      ),
                      _ActionBtn(
                        icon: 'lock_reset',
                        label: 'Mot de passe',
                        color: AppTheme.warning,
                        onTap: () => _resetPassword(user),
                      ),
                      _ActionBtn(
                        icon: user.isActive ? 'block' : 'check_circle',
                        label: user.isActive ? 'Désactiver' : 'Activer',
                        color: user.isActive
                            ? AppTheme.warning
                            : AppTheme.success,
                        onTap: () => _toggleAccount(user),
                      ),
                      _ActionBtn(
                        icon: 'delete_outline',
                        label: 'Supprimer',
                        color: AppTheme.critical,
                        onTap: () => _deleteUser(user),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E).withAlpha(15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomIconWidget(
                          iconName: 'shield',
                          color: const Color(0xFF1A237E),
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Compte protégé — non modifiable',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 11,
                            color: const Color(0xFF1A237E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

// ---------------------------------------------------------------------------
// Action button helper
// ---------------------------------------------------------------------------
class _ActionBtn extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomIconWidget(iconName: icon, color: color, size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Confirm button (async action inside dialog)
// ---------------------------------------------------------------------------
class _ConfirmButton extends StatefulWidget {
  final String label;
  final Color color;
  final Future<void> Function() onConfirm;
  final VoidCallback onSuccess;
  final void Function(String) onError;

  const _ConfirmButton({
    required this.label,
    required this.color,
    required this.onConfirm,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _loading
          ? null
          : () async {
              setState(() => _loading = true);
              try {
                await widget.onConfirm();
                if (context.mounted) Navigator.pop(context);
                widget.onSuccess();
              } catch (e) {
                if (context.mounted) Navigator.pop(context);
                widget.onError(e.toString().replaceFirst('Exception: ', ''));
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              widget.label,
              style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add User Sheet
// ---------------------------------------------------------------------------
class _AddUserSheet extends StatefulWidget {
  final void Function(_UserModel) onAdd;

  const _AddUserSheet({required this.onAdd});

  @override
  State<_AddUserSheet> createState() => _AddUserSheetState();
}

class _AddUserSheetState extends State<_AddUserSheet> {
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _selectedRole = 'Admin';
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _fullNameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final fullName = _fullNameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty ||
        username.isEmpty ||
        fullName.isEmpty ||
        password.isEmpty) {
      setState(() => _error = 'Veuillez remplir tous les champs.');
      return;
    }
    if (password.length < 6) {
      setState(
        () => _error = 'Le mot de passe doit contenir au moins 6 caractères.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await SupabaseService.instance.createUser(
        email: email,
        password: password,
        role: _selectedRole,
        username: username,
        fullName: fullName,
      );
      final userId = (data['id'] as String?) ?? username;
      try {
        await SupabaseService.instance.updateUserProfile(
          key: username,
          username: username,
          role: _selectedRole,
          organisation: 'Sonatrach-TRC RTH-HSE',
          site: 'Hassi Messaoud',
        );
      } catch (_) {}
      final newUser = _UserModel.fromSupabase(data);
      if (mounted) {
        Navigator.pop(context);
        widget.onAdd(newUser);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outlineVariantLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A237E).withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CustomIconWidget(
                    iconName: 'person_add',
                    color: const Color(0xFF1A237E),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Nouveau compte',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkCharcoal,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: CustomIconWidget(
                    iconName: 'close',
                    color: AppTheme.secondaryText,
                    size: 22,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.criticalContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.critical.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'error_outline',
                      color: AppTheme.critical,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 12,
                          color: AppTheme.critical,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            _buildField('Nom complet', _fullNameCtrl, 'ex: Ahmed Benali'),
            const SizedBox(height: 12),
            _buildField('Nom d\'utilisateur', _usernameCtrl, 'ex: abenali'),
            const SizedBox(height: 12),
            _buildField(
              'Adresse email',
              _emailCtrl,
              'ex: a.benali@sonatrach.dz',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _buildField(
              'Mot de passe',
              _passwordCtrl,
              'Min. 6 caractères',
              obscure: _obscurePassword,
              suffixIcon: IconButton(
                icon: CustomIconWidget(
                  iconName: _obscurePassword ? 'visibility_off' : 'visibility',
                  color: AppTheme.mutedText,
                  size: 18,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 12),

            // Role selector
            Text(
              'Rôle',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: ['Admin', 'User'].map((role) {
                final isSelected = _selectedRole == role;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: role == 'Admin' ? 8 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedRole = role),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1A237E).withAlpha(15)
                              : AppTheme.backgroundLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF1A237E)
                                : AppTheme.outlineVariantLight,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CustomIconWidget(
                              iconName: role == 'Admin'
                                  ? 'manage_accounts'
                                  : 'person',
                              color: isSelected
                                  ? const Color(0xFF1A237E)
                                  : AppTheme.secondaryText,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              role,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isSelected
                                    ? const Color(0xFF1A237E)
                                    : AppTheme.darkCharcoal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Créer le compte',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkCharcoal,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              color: AppTheme.mutedText,
            ),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.outlineVariantLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.outlineVariantLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF1A237E),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Edit User Sheet
// ---------------------------------------------------------------------------
class _EditUserSheet extends StatefulWidget {
  final _UserModel user;
  final void Function(String fullName, String email, String role) onSave;

  const _EditUserSheet({required this.user, required this.onSave});

  @override
  State<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<_EditUserSheet> {
  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _emailCtrl;
  late String _selectedRole;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fullNameCtrl = TextEditingController(text: widget.user.fullName);
    _emailCtrl = TextEditingController(text: widget.user.email);
    _selectedRole = widget.user.role == 'Super Admin'
        ? 'Admin'
        : widget.user.role;
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final fullName = _fullNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (fullName.isEmpty || email.isEmpty) {
      setState(() => _error = 'Veuillez remplir tous les champs.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await SupabaseService.instance.updateUserMetadata(
        userId: widget.user.id,
        role: _selectedRole,
        username: widget.user.username,
        fullName: fullName,
        email: email,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSave(fullName, email, _selectedRole);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outlineVariantLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CustomIconWidget(
                    iconName: 'edit',
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Modifier le compte',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkCharcoal,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: CustomIconWidget(
                    iconName: 'close',
                    color: AppTheme.secondaryText,
                    size: 22,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.criticalContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.critical.withAlpha(80)),
                ),
                child: Text(
                  _error!,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    color: AppTheme.critical,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            _buildField('Nom complet', _fullNameCtrl, widget.user.fullName),
            const SizedBox(height: 12),
            _buildField(
              'Email',
              _emailCtrl,
              widget.user.email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),

            Text(
              'Rôle',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: ['Admin', 'User'].map((role) {
                final isSelected = _selectedRole == role;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: role == 'Admin' ? 8 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedRole = role),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withAlpha(15)
                              : AppTheme.backgroundLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.outlineVariantLight,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CustomIconWidget(
                              iconName: role == 'Admin'
                                  ? 'manage_accounts'
                                  : 'person',
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.secondaryText,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              role,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.darkCharcoal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Enregistrer les modifications',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkCharcoal,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              color: AppTheme.mutedText,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.outlineVariantLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.outlineVariantLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }
}
