import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          onPressed: () => Navigator.of(context).pop(),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                    'Développé par Haitham BADEREDDINE',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
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
                widget.username.isNotEmpty
                    ? widget.username[0].toUpperCase()
                    : 'A',
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
            widget.username,
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
              child: Text(
                'Informations du compte',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedText,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            _buildInfoTile(
              icon: 'person',
              label: 'Nom d\'utilisateur',
              value: widget.username,
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
              value: 'Sonatrach — TRC RTH',
            ),
            _buildDivider(),
            _buildInfoTile(
              icon: 'location_on',
              label: 'Site',
              value: 'Hassi Messaoud',
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
              if (mounted) {
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
