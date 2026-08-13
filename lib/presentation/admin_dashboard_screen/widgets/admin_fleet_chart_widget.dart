import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class AdminFleetChartWidget extends StatefulWidget {
  final int operational;
  final int maintenance;
  final int outOfService;

  const AdminFleetChartWidget({
    super.key,
    this.operational = 4,
    this.maintenance = 1,
    this.outOfService = 1,
  });

  @override
  State<AdminFleetChartWidget> createState() => _AdminFleetChartWidgetState();
}

class _AdminFleetChartWidgetState extends State<AdminFleetChartWidget> {
  final int _touchedIndex = -1;

  // Mock: daily operational count over last 14 days
  // X = day offset from today (0 = today), Y = vehicles operational
  final List<FlSpot> _operationalSpots = const [
    FlSpot(0, 4),
    FlSpot(1, 4),
    FlSpot(2, 3),
    FlSpot(3, 3),
    FlSpot(4, 4),
    FlSpot(5, 5),
    FlSpot(6, 5),
    FlSpot(7, 4),
    FlSpot(8, 4),
    FlSpot(9, 4),
    FlSpot(10, 3),
    FlSpot(11, 3),
    FlSpot(12, 4),
    FlSpot(13, 4),
  ];

  final List<FlSpot> _maintenanceSpots = const [
    FlSpot(0, 1),
    FlSpot(1, 1),
    FlSpot(2, 2),
    FlSpot(3, 2),
    FlSpot(4, 1),
    FlSpot(5, 0),
    FlSpot(6, 0),
    FlSpot(7, 1),
    FlSpot(8, 1),
    FlSpot(9, 1),
    FlSpot(10, 2),
    FlSpot(11, 2),
    FlSpot(12, 1),
    FlSpot(13, 1),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariantLight, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0D17202A),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Row(
            children: [
              _LegendItem(color: AppTheme.success, label: 'Opérationnels'),
              const SizedBox(width: 16),
              _LegendItem(color: AppTheme.warning, label: 'En maintenance'),
            ],
          ),
          const SizedBox(height: 16),

          // Chart
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppTheme.outlineVariantLight,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 10,
                          color: AppTheme.mutedText,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 2,
                      reservedSize: 20,
                      getTitlesWidget: (value, meta) {
                        final dayOffset = 13 - value.toInt();
                        if (dayOffset % 2 != 0) {
                          return const SizedBox.shrink();
                        }
                        final date = DateTime(
                          2026,
                          8,
                          12,
                        ).subtract(Duration(days: dayOffset));
                        return Text(
                          '${date.day}/${date.month}',
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 9,
                            color: AppTheme.mutedText,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 13,
                minY: 0,
                maxY: 6,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: AppTheme.darkCharcoal,
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (spots) => spots.map((spot) {
                      final isOperational = spot.barIndex == 0;
                      return LineTooltipItem(
                        '${spot.y.toInt()} ${isOperational ? 'opér.' : 'maint.'}',
                        GoogleFonts.ibmPlexMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isOperational
                              ? AppTheme.success
                              : AppTheme.warning,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  // Operational line
                  LineChartBarData(
                    spots: _operationalSpots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppTheme.success,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.success.withAlpha(51),
                          AppTheme.success.withAlpha(0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Maintenance line
                  LineChartBarData(
                    spots: _maintenanceSpots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppTheme.warning,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.warning.withAlpha(26),
                          AppTheme.warning.withAlpha(0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          Text(
            'Données des 14 derniers jours — Parc RTH',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 10,
              color: AppTheme.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 11,
            color: AppTheme.secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
