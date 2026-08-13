import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class ScannerFrameWidget extends StatelessWidget {
  final Animation<double> scanLineAnimation;
  final bool isProcessing;

  const ScannerFrameWidget({
    super.key,
    required this.scanLineAnimation,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Semi-transparent overlay with hole
        CustomPaint(size: Size.infinite, painter: _ScannerOverlayPainter()),

        // Corner decorations
        ..._buildCorners(),

        // Animated scan line
        if (!isProcessing)
          AnimatedBuilder(
            animation: scanLineAnimation,
            builder: (context, child) {
              return Positioned(
                top:
                    4 +
                    scanLineAnimation.value *
                        (double.infinity.isNaN ? 200 : 200),
                left: 4,
                right: 4,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppTheme.primary.withAlpha(204),
                        AppTheme.primary,
                        AppTheme.primary.withAlpha(204),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withAlpha(128),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

        // Processing overlay
        if (isProcessing)
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(38),
              border: Border.all(color: AppTheme.primary, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildCorners() {
    const cornerSize = 28.0;
    const cornerThickness = 4.0;
    const cornerColor = AppTheme.primary;

    return [
      // Top-left
      Positioned(
        top: 0,
        left: 0,
        child: _Corner(
          topLeft: true,
          size: cornerSize,
          thickness: cornerThickness,
          color: cornerColor,
        ),
      ),
      // Top-right
      Positioned(
        top: 0,
        right: 0,
        child: _Corner(
          topRight: true,
          size: cornerSize,
          thickness: cornerThickness,
          color: cornerColor,
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: 0,
        left: 0,
        child: _Corner(
          bottomLeft: true,
          size: cornerSize,
          thickness: cornerThickness,
          color: cornerColor,
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: 0,
        right: 0,
        child: _Corner(
          bottomRight: true,
          size: cornerSize,
          thickness: cornerThickness,
          color: cornerColor,
        ),
      ),
    ];
  }
}

class _Corner extends StatelessWidget {
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;
  final double size;
  final double thickness;
  final Color color;

  const _Corner({
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
    required this.size,
    required this.thickness,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
          thickness: thickness,
          color: color,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;
  final double thickness;
  final Color color;

  _CornerPainter({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
    required this.thickness,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    if (topLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (topRight) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (bottomLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else if (bottomRight) {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withAlpha(0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_ScannerOverlayPainter old) => false;
}
