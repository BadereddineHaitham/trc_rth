import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';

class ProfileScreen extends StatefulWidget {
  final String role;
  final String username;

  const ProfileScreen({
    super.key,
    this.role = 'Admin',
    this.username = 'admin',
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;
  final _svc = SupabaseService.instance;

  String _username = '';
  String _organisation = 'Sonatrach-TRC RTH-HSE';
  String _site = 'Hassi Messaoud';
  RealtimeChannel? _settingsChannel;

  bool get _isSuperAdmin => widget.role == 'Super Admin';
  bool get _canEditProfile => widget.role == 'Super Admin' || widget.role == 'Admin';

  String get _userId => _svc.currentUser?.id ?? widget.username;

  @override
  void initState() {
    super.initState();
    _username = widget.username.isNotEmpty ? widget.username : 'Utilisateur';
    _loadSettings();
    _subscribeSettingsRealtime();
  }

  @override
  void dispose() {
    _settingsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final profile = await _svc.getUserProfile(
      _userId,
      defaultUsername: widget.username,
      defaultRole: widget.role,
    );
    if (mounted) {
      setState(() {
        final u = (profile['username'] as String?)?.trim() ?? '';
        if (u.isNotEmpty) {
          _username = u;
        } else if (widget.username.isNotEmpty) {
          _username = widget.username;
        }
        final org = (profile['organisation'] as String?)?.trim() ?? '';
        if (org.isNotEmpty) _organisation = org;
        final st = (profile['site'] as String?)?.trim() ?? '';
        if (st.isNotEmpty) _site = st;
      });
    }
  }

  void _subscribeSettingsRealtime() {
    _settingsChannel = _svc.client
        .channel('user_profiles_realtime_$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_profiles',
          callback: (_) => _loadSettings(),
        )
        .subscribe();
  }

  void _showEditAccountSheet() {
    if (!_canEditProfile) return;
    final userCtrl = TextEditingController(text: _username);
    final orgCtrl = TextEditingController(text: _organisation);
    final siteCtrl = TextEditingController(text: _site);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                      'Modifier les informations du compte',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkCharcoal,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom d\'utilisateur',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: orgCtrl,
                decoration: const InputDecoration(
                  labelText: 'Organisation',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: siteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Site',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setModalState(() => isSaving = true);
                          try {
                            await _svc.updateUserProfile(
                              key: _userId,
                              username: userCtrl.text.trim(),
                              role: widget.role,
                              organisation: orgCtrl.text.trim(),
                              site: siteCtrl.text.trim(),
                            );
                            if (mounted) {
                              setState(() {
                                _username = userCtrl.text.trim();
                                _organisation = orgCtrl.text.trim();
                                _site = siteCtrl.text.trim();
                              });
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Informations du compte mises à jour en temps réel',
                                    style: GoogleFonts.ibmPlexSans(
                                        color: Colors.white),
                                  ),
                                  backgroundColor: AppTheme.success,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isSaving = false);
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
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
    } else if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    } else {
      if (_isSuperAdmin) {
        context.go(AppRoutes.superAdminDashboardScreen);
      } else if (widget.role == 'Admin') {
        context.go(
          AppRoutes.adminDashboardScreen,
          extra: {'role': widget.role, 'username': widget.username},
        );
      } else {
        context.go(AppRoutes.parkHomeScreen, extra: widget.role);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppTheme.darkCharcoal,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
            onPressed: _handleBackNavigation,
            tooltip: 'Retour',
          ),
          title: Text(
            'Profil',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildProfileHeader(context),
              const SizedBox(height: 16),
              _buildInfoSection(context),
              const SizedBox(height: 16),
              _buildActionsSection(context),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () async {
                  final Uri url = Uri.parse('https://wa.me/213553237642');
                  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                    await launchUrl(url);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primary.withAlpha(40)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomIconWidget(
                        iconName: 'code',
                        color: AppTheme.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Développé par Haitham BADEREDDINE 💬',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.darkCharcoal, Color(0xFF1E2C3A)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(51), width: 3),
            ),
            child: Center(
              child: Text(
                _username.isNotEmpty ? _username[0].toUpperCase() : 'A',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _username,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: widget.role == 'Super Admin'
                  ? AppTheme.primary.withAlpha(51)
                  : Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.role == 'Super Admin'
                    ? AppTheme.primary.withAlpha(153)
                    : Colors.white.withAlpha(51),
              ),
            ),
            child: Text(
              widget.role,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.role == 'Super Admin'
                    ? AppTheme.primary
                    : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.outlineVariantLight),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkCharcoal.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Informations du compte',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  if (_isSuperAdmin)
                    InkWell(
                      onTap: _showEditAccountSheet,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.edit,
                                size: 14, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Modifier',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 12,
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
            ),
            _buildInfoTile(
              icon: 'person',
              label: 'Nom d\'utilisateur',
              value: _username,
            ),
            _buildDivider(),
            _buildInfoTile(
              icon: 'badge',
              label: 'Rôle',
              value: widget.role,
              valueColor: widget.role == 'Super Admin'
                  ? AppTheme.primary
                  : null,
            ),
            _buildDivider(),
            _buildInfoTile(
              icon: 'business',
              label: 'Organisation',
              value: _organisation,
            ),
            _buildDivider(),
            _buildInfoTile(
              icon: 'location_on',
              label: 'Site',
              value: _site,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required String icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariantLight,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: CustomIconWidget(
                iconName: icon,
                color: AppTheme.secondaryText,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    color: AppTheme.mutedText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppTheme.darkCharcoal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 64,
      endIndent: 16,
      color: AppTheme.outlineVariantLight,
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.outlineVariantLight),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkCharcoal.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Actions',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedText,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            _buildActionTile(
              context: context,
              icon: 'lock_reset',
              label: 'Changer le mot de passe',
              onTap: () => _showChangePasswordDialog(context),
            ),
            _buildDivider(),
            _buildActionTile(
              context: context,
              icon: 'logout',
              label: 'Se déconnecter',
              color: AppTheme.critical,
              onTap: _isLoggingOut ? null : () => _showLogoutDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required String icon,
    required String label,
    required VoidCallback? onTap,
    Color? color,
  }) {
    final tileColor = color ?? AppTheme.darkCharcoal;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color != null
                    ? color.withAlpha(26)
                    : AppTheme.surfaceVariantLight,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: _isLoggingOut && color == AppTheme.critical
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : CustomIconWidget(
                        iconName: icon,
                        color: tileColor,
                        size: 18,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tileColor,
                ),
              ),
            ),
            CustomIconWidget(
              iconName: 'chevron_right',
              color: AppTheme.mutedText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Changer le mot de passe',
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.w700,
            color: AppTheme.darkCharcoal,
          ),
        ),
        content: Text(
          'Cette fonctionnalité sera disponible prochainement.',
          style: GoogleFonts.ibmPlexSans(color: AppTheme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'OK',
              style: GoogleFonts.ibmPlexSans(color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Se déconnecter',
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.w700,
            color: AppTheme.darkCharcoal,
          ),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
          style: GoogleFonts.ibmPlexSans(color: AppTheme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Annuler',
              style: GoogleFonts.ibmPlexSans(color: AppTheme.mutedText),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoggingOut = true);
              try {
                await SupabaseService.instance.signOut();
              } catch (_) {
                // Proceed to login even if signOut fails
              }
              await Future.microtask(() {});
              if (mounted && context.mounted) {
                context.go(AppRoutes.adminLoginScreen);
              }
            },
            child: Text(
              'Déconnecter',
              style: GoogleFonts.ibmPlexSans(
                color: AppTheme.critical,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
