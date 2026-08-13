import 'package:flutter/material.dart';

import '../../../../core/app_export.dart';

class VehicleStatusHeaderWidget extends StatelessWidget {
  final Map<String, dynamic> vehicle;

  const VehicleStatusHeaderWidget({super.key, required this.vehicle});

  String get _statusLabel {
    switch (vehicle['status'] as String) {
      case 'operational':
        return 'OPÉRATIONNEL';
      case 'maintenance':
        return 'EN MAINTENANCE';
      case 'out_of_service':
        return 'HORS SERVICE';
      default:
        return 'INDISPONIBLE';
    }
  }

  Color get _statusDotColor {
    switch (vehicle['status'] as String) {
      case 'operational':
        return const Color(0xFF4ADE80);
      case 'maintenance':
        return const Color(0xFFFBBF24);
      case 'out_of_service':
        return const Color(0xFFF87171);
      default:
        return const Color(0xFFB0BEC5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                vehicle['name'] as String,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(38),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withAlpha(64),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _statusDotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _statusLabel,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(26),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      vehicle['type'] as String,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 11,
                        color: Colors.white.withAlpha(204),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(31),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(51), width: 1),
          ),
          child: Center(
            child: CustomIconWidget(
              iconName: 'fire_truck',
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}
