// lib/features/analytics/presentation/widgets/energy_pattern_chart.dart
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/energy_pattern_data.dart';

class EnergyPatternChart extends StatefulWidget {
  final EnergyPatternData patterns;

  const EnergyPatternChart({
    super.key,
    required this.patterns,
  });

  @override
  State<EnergyPatternChart> createState() => _EnergyPatternChartState();
}

class _EnergyPatternChartState extends State<EnergyPatternChart> 
    with SingleTickerProviderStateMixin {
  final _logger = Logger('EnergyPatternChart');
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _logger.fine('Initializing EnergyPatternChart');
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _logger.finest('Building EnergyPatternChart');
    
    return Container(
      height: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your ${widget.patterns.chronoType.displayName} Pattern',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.patterns.chronoType.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: EnergyChartPainter(
                    patterns: widget.patterns,
                    animationValue: _animation.value,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Low', AppColors.error),
        const SizedBox(width: 24),
        _buildLegendItem('Medium', AppColors.warning),
        const SizedBox(width: 24),
        _buildLegendItem('High', AppColors.success),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class EnergyChartPainter extends CustomPainter {
  final EnergyPatternData patterns;
  final double animationValue;
  final _logger = Logger('EnergyChartPainter');

  EnergyChartPainter({
    required this.patterns,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _logger.finest('Painting energy chart');
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withOpacity(0.3),
          AppColors.primary.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Draw grid lines
    _drawGrid(canvas, size);

    // Draw energy curve
    final path = Path();
    final fillPath = Path();
    
    final hourWidth = size.width / 23;
    final maxEnergy = 100.0;
    
    for (int i = 0; i < patterns.hourlyPattern.length; i++) {
      final hourData = patterns.hourlyPattern[i];
      final x = i * hourWidth;
      final y = size.height - (hourData.averageEnergy / maxEnergy * size.height * animationValue);
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        // Smooth curve using quadratic bezier
        final prevHour = patterns.hourlyPattern[i - 1];
        final prevX = (i - 1) * hourWidth;
        final prevY = size.height - (prevHour.averageEnergy / maxEnergy * size.height * animationValue);
        
        final cpX = (prevX + x) / 2;
        final cpY = (prevY + y) / 2;
        
        path.quadraticBezierTo(cpX, prevY, cpX, cpY);
        path.quadraticBezierTo(cpX, y, x, y);
        
        fillPath.quadraticBezierTo(cpX, prevY, cpX, cpY);
        fillPath.quadraticBezierTo(cpX, y, x, y);
      }
    }
    
    // Complete fill path
    fillPath.lineTo((patterns.hourlyPattern.length - 1) * hourWidth, size.height);
    fillPath.close();
    
    // Draw fill
    canvas.drawPath(fillPath, fillPaint);
    
    // Draw line with gradient based on energy level
    for (int i = 0; i < patterns.hourlyPattern.length - 1; i++) {
      final hourData = patterns.hourlyPattern[i];
      final nextHourData = patterns.hourlyPattern[i + 1];
      
      final x1 = i * hourWidth;
      final y1 = size.height - (hourData.averageEnergy / maxEnergy * size.height * animationValue);
      final x2 = (i + 1) * hourWidth;
      final y2 = size.height - (nextHourData.averageEnergy / maxEnergy * size.height * animationValue);
      
      paint.color = _getEnergyColor(hourData.averageEnergy);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
    
    // Draw peak and low markers
    _drawPeakMarkers(canvas, size, hourWidth);
    
    // Draw hour labels
    _drawHourLabels(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.borderSubtle.withOpacity(0.3)
      ..strokeWidth = 1;

    // Horizontal lines
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
  }

  void _drawPeakMarkers(Canvas canvas, Size size, double hourWidth) {
    // Peak marker
    final peakX = patterns.peakEnergyHour * hourWidth;
    final peakData = patterns.hourlyPattern[patterns.peakEnergyHour];
    final peakY = size.height - (peakData.averageEnergy / 100 * size.height * animationValue);
    
    final peakPaint = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(peakX, peakY), 6, peakPaint);
    
    // Low marker
    final lowX = patterns.lowestEnergyHour * hourWidth;
    final lowData = patterns.hourlyPattern[patterns.lowestEnergyHour];
    final lowY = size.height - (lowData.averageEnergy / 100 * size.height * animationValue);
    
    final lowPaint = Paint()
      ..color = AppColors.error
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(lowX, lowY), 6, lowPaint);
  }

  void _drawHourLabels(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final hourWidth = size.width / 23;
    
    for (int i = 0; i < 24; i += 4) {
      final x = i * hourWidth;
      
      textPainter.text = TextSpan(
        text: '${i.toString().padLeft(2, '0')}:00',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
        ),
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height + 8),
      );
    }
  }

  Color _getEnergyColor(double energy) {
    if (energy >= 80) return AppColors.success;
    if (energy >= 60) return AppColors.primary;
    if (energy >= 40) return AppColors.warning;
    return AppColors.error;
  }

  @override
  bool shouldRepaint(EnergyChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}