import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_export.dart';
import '../../services/supabase_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await SupabaseService.instance.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      Fluttertoast.showToast(
        msg: 'Connexion réussie — ${result['role']}',
        backgroundColor: AppTheme.success,
        textColor: Colors.white,
        gravity: ToastGravity.TOP,
      );

      if (result['role'] == 'Super Admin') {
        context.go(
          AppRoutes.superAdminDashboardScreen,
          extra: {'username': result['username']!},
        );
      } else if (result['role'] == 'Admin') {
        context.go(
          AppRoutes.adminDashboardScreen,
          extra: {'role': result['role']!, 'username': result['username']!},
        );
      } else {
        context.go(AppRoutes.qrScannerScreen);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _mapAuthError(e.message);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Une erreur est survenue. Veuillez réessayer.';
      });
    }
  }

  void _showPasswordResetDialog() {
    final resetEmailCtrl = TextEditingController(text: _emailController.text);
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            'Réinitialiser le mot de passe',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkCharcoal,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Entrez votre adresse email pour recevoir un lien de réinitialisation.',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  color: AppTheme.mutedText,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: resetEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 14,
                  color: AppTheme.darkCharcoal,
                ),
                decoration: InputDecoration(
                  labelText: 'Adresse email',
                  hintText: 'votre@email.com',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CustomIconWidget(
                      iconName: 'email_outlined',
                      color: AppTheme.mutedText,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isResetting ? null : () => Navigator.pop(ctx),
              child: Text(
                'Annuler',
                style: GoogleFonts.ibmPlexSans(color: AppTheme.mutedText),
              ),
            ),
            ElevatedButton(
              onPressed: isResetting
                  ? null
                  : () async {
                      final email = resetEmailCtrl.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        Fluttertoast.showToast(
                          msg: 'Veuillez saisir une adresse email valide.',
                          backgroundColor: AppTheme.warning,
                        );
                        return;
                      }

                      setDialogState(() => isResetting = true);
                      try {
                        await SupabaseService.instance
                            .sendPasswordResetEmail(email);
                        if (ctx.mounted) Navigator.pop(ctx);
                        Fluttertoast.showToast(
                          msg: 'Email de réinitialisation envoyé !',
                          backgroundColor: AppTheme.success,
                          gravity: ToastGravity.TOP,
                        );
                      } catch (e) {
                        setDialogState(() => isResetting = false);
                        Fluttertoast.showToast(
                          msg: e.toString().replaceAll('Exception: ', ''),
                          backgroundColor: AppTheme.critical,
                          gravity: ToastGravity.TOP,
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isResetting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Envoyer',
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

  String _mapAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login') ||
        lower.contains('invalid credentials')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Veuillez confirmer votre adresse email.';
    }
    if (lower.contains('too many requests')) {
      return 'Trop de tentatives. Veuillez patienter avant de réessayer.';
    }
    if (lower.contains('network') || lower.contains('connection')) {
      return 'Erreur de connexion réseau. Vérifiez votre connexion.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet ? 480 : double.infinity,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 0 : 24,
                      vertical: 32,
                    ),
                    child: isTablet
                        ? Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(
                                color: AppTheme.outlineVariantLight,
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: _buildFormContent(),
                            ),
                          )
                        : _buildFormContent(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Back button
          Row(
            children: [
              IconButton(
                icon: CustomIconWidget(
                  iconName: 'arrow_back',
                  color: AppTheme.darkCharcoal,
                  size: 22,
                ),
                onPressed: () => context.go(AppRoutes.qrScannerScreen),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),

          // Logo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withAlpha(38),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: AppTheme.outlineVariantLight, width: 1),
            ),
            padding: const EdgeInsets.all(10),
            child: CustomImageWidget(
              imageUrl: 'assets/images/logo-1786569551645.jpeg',
              width: 60,
              height: 60,
              fit: BoxFit.contain,
              semanticLabel: 'Logo Sonatrach',
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'TRC RTH',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkCharcoal,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Administration',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.mutedText,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 48,
            height: 3,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),

          // Error message
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.criticalContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.critical.withAlpha(77),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomIconWidget(
                    iconName: 'error_outline',
                    color: AppTheme.critical,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        color: AppTheme.critical,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              color: AppTheme.darkCharcoal,
            ),
            decoration: InputDecoration(
              labelText: 'Adresse email',
              hintText: 'votre@email.com',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: CustomIconWidget(
                  iconName: 'email_outlined',
                  color: AppTheme.mutedText,
                  size: 22,
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Veuillez saisir votre adresse email';
              }
              if (!v.contains('@')) {
                return 'Adresse email invalide';
              }
              return null;
            },
            onChanged: (_) => setState(() => _errorMessage = null),
          ),
          const SizedBox(height: 14),

          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              color: AppTheme.darkCharcoal,
            ),
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              hintText: 'Votre mot de passe',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: CustomIconWidget(
                  iconName: 'lock_outline',
                  color: AppTheme.mutedText,
                  size: 22,
                ),
              ),
              suffixIcon: IconButton(
                icon: CustomIconWidget(
                  iconName: _obscurePassword ? 'visibility_off' : 'visibility',
                  color: AppTheme.mutedText,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Veuillez saisir votre mot de passe';
              }
              return null;
            },
            onFieldSubmitted: (_) => _login(),
            onChanged: (_) => setState(() => _errorMessage = null),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showPasswordResetDialog,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Mot de passe oublié ?',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Login button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                disabledBackgroundColor: AppTheme.primary.withAlpha(153),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Connexion',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 28),

          // Security notice & Developer mark
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomIconWidget(
                    iconName: 'security',
                    color: AppTheme.mutedText,
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Accès sécurisé — Sonatrach-TRC RTH-HSE',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      color: AppTheme.mutedText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final Uri url = Uri.parse('https://wa.me/213553237642');
                  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                    await launchUrl(url);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
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
                        size: 13,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Développé par Haitham BADEREDDINE 💬',
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
  );
}
}
