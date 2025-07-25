import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class EnergyGraph extends StatelessWidget {
  final List<int> energyLevels;
  final int currentHour;

  const EnergyGraph({
    super.key,
    required this.energyLevels,
    required this.currentHour,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Stack(
        children: [
          // Graph background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.success.withValues(alpha: 0.1),
                  AppColors.focus.withValues(alpha: 0.05),
                  AppColors.primaryDark.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          // Custom paint for graph
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CustomPaint(
              size: Size.infinite,
              painter: EnergyGraphPainter(
                energyLevels: energyLevels,
                currentHour: currentHour,
              ),
            ),
          ),
          // Current time marker
          Positioned(
            left: (currentHour / 24) * MediaQuery.of(context).size.width - 41,
            top: 0,
            bottom: 0,
            child: Container(
              width: 2,
              color: AppColors.warning,
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.warning,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.warning.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EnergyGraphPainter extends CustomPainter {
  final List<int> energyLevels;
  final int currentHour;

  EnergyGraphPainter({
    required this.energyLevels,
    required this.currentHour,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final path = Path();

    for (int i = 0; i < energyLevels.length; i++) {
      final x = (i / energyLevels.length) * size.width;
      final y = size.height - (energyLevels[i] / 100 * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Smooth curve
        final prevX = ((i - 1) / energyLevels.length) * size.width;
        final prevY = size.height - (energyLevels[i - 1] / 100 * size.height);
        final cpX = (prevX + x) / 2;
        path.quadraticBezierTo(cpX, prevY, x, y);
      }
    }

    // Create gradient shader
    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        AppColors.success,
        AppColors.focus,
        AppColors.primary,
        AppColors.primaryDark,
      ],
    );

    paint.shader = gradient.createShader(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}