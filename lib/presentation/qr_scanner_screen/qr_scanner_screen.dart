import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/app_export.dart';
import '../../services/supabase_service.dart';
import './widgets/manual_entry_widget.dart';
import './widgets/scanner_frame_widget.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with TickerProviderStateMixin {
  bool _isProcessing = false;
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );

  StreamSubscription<BarcodeCapture>? _barcodeSubscription;
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      try {
        MobileScannerPlatform.instance
            .setBarcodeLibraryScriptUrl('zxing.min.js');
      } catch (_) {}
    }

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );

    // Guaranteed listener for both Web and native platforms
    _barcodeSubscription = _scannerController.barcodes.listen(_onDetect);

    // If opened via web link with ?qr=... or ?code=..., process directly
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkInitialUrlParams();
      });
    }
  }

  void _checkInitialUrlParams() {
    try {
      final uri = Uri.base;
      final param = uri.queryParameters['qr'] ??
          uri.queryParameters['code'] ??
          uri.queryParameters['park'] ??
          uri.queryParameters['scan'];
      if (param != null && param.trim().isNotEmpty) {
        _processQrCode(param.trim());
      }
    } catch (_) {}
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue ?? barcode.displayValue;
      if (code != null && code.trim().isNotEmpty) {
        _processQrCode(code);
        break;
      }
    }
  }

  Future<void> _processQrCode(String code) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final cleanCode = code.trim();
      final lower = cleanCode.toLowerCase();
      final upper = cleanCode.toUpperCase();
      final normalized =
          upper.replaceAll('-', '').replaceAll('_', '').replaceAll(' ', '');

      // ── STRICT WHITELIST OF OUR AUTHORIZED QR CODES ────────────────────────

      // 1. User's generated QR code (me-qr.com link: rm1fhboz or any me-qr for park)
      final bool isUserQr =
          lower.contains('rm1fhboz') || lower.contains('me-qr.com');

      // 2. Official Sonatrach TRC RTH park code (direct QR or variants)
      final bool isOfficialPark =
          upper == 'TRC-RTH-PARK-001' ||
          upper == 'RTH-PARK-001' ||
          upper == 'TRC_RTH_PARK_001' ||
          upper == 'RTH_PARK_001' ||
          upper == 'PARK-001' ||
          normalized.contains('TRCRTHPARK') ||
          normalized.contains('RTHPARK001');

      if (isUserQr || isOfficialPark) {
        Fluttertoast.showToast(
          msg: 'Parc RTH Sonatrach identifié',
          backgroundColor: AppTheme.success,
          textColor: Colors.white,
          gravity: ToastGravity.TOP,
          toastLength: Toast.LENGTH_SHORT,
        );

        context.go(
          AppRoutes.parkHomeScreen,
          extra: {'role': 'User'},
        );
        return;
      }

      // 3. Exact match with registered park in database (eq qr_code)
      final park = await SupabaseService.instance.getParkByQrCode(cleanCode);
      if (!mounted) return;

      if (park != null) {
        Fluttertoast.showToast(
          msg: 'Parc identifié: ${park['name'] ?? 'RTH Sonatrach'}',
          backgroundColor: AppTheme.success,
          textColor: Colors.white,
          gravity: ToastGravity.TOP,
          toastLength: Toast.LENGTH_SHORT,
        );

        context.go(
          AppRoutes.parkHomeScreen,
          extra: {
            'role': 'User',
            'parkId': park['id'] as String?,
          },
        );
        return;
      }

      // 4. Exact match with registered vehicle matricule
      final vehicle = await SupabaseService.instance.getVehicleByCode(cleanCode);
      if (!mounted) return;

      if (vehicle != null) {
        Fluttertoast.showToast(
          msg: 'Véhicule identifié: ${vehicle['name'] ?? ''}',
          backgroundColor: AppTheme.success,
          textColor: Colors.white,
          gravity: ToastGravity.TOP,
          toastLength: Toast.LENGTH_SHORT,
        );

        context.go(
          AppRoutes.vehicleDetailsScreen,
          extra: {
            'vehicleId': vehicle['id'] as String,
            'role': 'User',
          },
        );
        return;
      }

      // ── REJECT ANY OTHER QR CODE ──────────────────────────────────────────
      _onInvalidScan();
    } catch (e) {
      if (mounted) {
        _onInvalidScan();
      }
    } finally {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() => _isProcessing = false);
          }
        });
      }
    }
  }

  void _onInvalidScan() {
    Fluttertoast.showToast(
      msg: 'QR Code non autorisé.\nScannez uniquement le QR Code officiel TRC RTH.',
      backgroundColor: AppTheme.critical,
      textColor: Colors.white,
      gravity: ToastGravity.TOP,
      toastLength: Toast.LENGTH_LONG,
    );
  }

  void _showManualEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ManualEntryWidget(
        onSubmit: (code) {
          Navigator.pop(ctx);
          _processQrCode(code);
        },
      ),
    );
  }

  @override
  void dispose() {
    _barcodeSubscription?.cancel();
    _scanLineController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.darkCharcoal,
      body: Stack(
        children: [
          // Dark background
          Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF0D1117),
          ),

          // Camera viewfinder area
          Positioned.fill(
            child: Stack(
              children: [
                Positioned.fill(
                  child: MobileScanner(
                    controller: _scannerController,
                    onDetect: _onDetect,
                    errorBuilder: (context, error, child) {
                      return Container(
                        color: const Color(0xFF0D1117),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CustomIconWidget(
                              iconName: 'camera_alt',
                              color: AppTheme.mutedText,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Caméra indisponible ou permission refusée',
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Center(
                  child: SizedBox(
                    width: size.width * 0.75,
                    height: size.width * 0.75,
                    child: ScannerFrameWidget(
                      scanLineAnimation: _scanLineAnimation,
                      isProcessing: _isProcessing,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content overlay
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                const Spacer(),

                // Bottom actions with official QR notice clearly placed at bottom
                _buildBottomActions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Column(
        children: [
          // Logo row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(3),
                child: CustomImageWidget(
                  imageUrl: 'assets/images/logo-1786569551645.jpeg',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                  semanticLabel: 'Logo Sonatrach',
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRC RTH',
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'Gestion des véhicules d\'incendie',
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withAlpha(140),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Scanner le QR Code du parc',
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Positionnez le QR Code dans le cadre pour accéder au parc',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withAlpha(140),
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scanner status indicator / label: placed outside and below the scan square
          if (!_isProcessing)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2430),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primary.withAlpha(100),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomIconWidget(
                      iconName: 'qr_code_scanner',
                      color: AppTheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Scannez le QR Code officiel',
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_isProcessing)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Validation du QR Code...',
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withAlpha(220),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Manual entry button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showManualEntry,
              icon: CustomIconWidget(
                iconName: 'keyboard',
                color: Colors.white.withAlpha(204),
                size: 18,
              ),
              label: Text(
                'Saisir le code manuellement',
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.white.withAlpha(204),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withAlpha(64), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Admin access
          TextButton(
            onPressed: () => context.go(AppRoutes.adminLoginScreen),
            child: Text(
              'Accès Administration',
              style: GoogleFonts.ibmPlexSans(
                color: AppTheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Code démo: TRC-RTH-PARK-001',
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withAlpha(77),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Idée & Spécifications Métier : Walid SOLTANI',
            style: GoogleFonts.ibmPlexSans(
              color: const Color(0xFFFFB74D),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
