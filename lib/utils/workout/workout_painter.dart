import 'package:flutter/material.dart';
import 'workout_parser.dart';
import 'workout_constants.dart';

class WorkoutPainter extends CustomPainter {
  final List<WorkoutSegment> segments;
  final double maxPower;
  final double totalDuration;
  final double ftpValue;

  WorkoutPainter({
    required this.segments,
    required this.maxPower,
    required this.totalDuration,
    required this.ftpValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.fill;

    double currentX = 0;
    final heightScale = size.height / (maxPower * ftpValue);
    final widthScale = size.width / totalDuration;

    // Draw segments
    for (var segment in segments) {
      paint.color = _getSegmentColor(segment);
      final segmentWidth = segment.duration * widthScale;
      
      if (segment.isRamp) {
        // Draw ramp segment
        final path = Path();
        final startHeight = size.height - (segment.powerLow * ftpValue * heightScale);
        final endHeight = size.height - (segment.powerHigh * ftpValue * heightScale);
        
        path.moveTo(currentX, size.height);
        path.lineTo(currentX, startHeight);
        path.lineTo(currentX + segmentWidth, endHeight);
        path.lineTo(currentX + segmentWidth, size.height);
        path.close();
        
        canvas.drawPath(path, paint);
      } else {
        // Draw steady state segment
        final segmentHeight = segment.powerLow * ftpValue * heightScale;
        final rect = Rect.fromLTWH(
          currentX,
          size.height - segmentHeight,
          segmentWidth,
          segmentHeight,
        );
        canvas.drawRect(rect, paint);
      }

      // Draw segment border
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.black.withOpacity(WorkoutOpacity.segmentBorder)
        ..strokeWidth = WorkoutStroke.border;
      
      canvas.drawRect(
        Rect.fromLTWH(currentX, 0, segmentWidth, size.height),
        borderPaint,
      );

      // Draw cadence indicator if present
      if (segment.cadence != null || segment.cadenceLow != null) {
        _drawCadenceIndicator(canvas, currentX, segmentWidth, size.height, segment);
      }

      currentX += segmentWidth;
    }

    // Draw power grid lines and labels
    _drawPowerGrid(canvas, size, heightScale);
    
    // Draw time grid lines and labels
    _drawTimeGrid(canvas, size, widthScale);
  }

  void _drawPowerGrid(Canvas canvas, Size size, double heightScale) {
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey.withOpacity(WorkoutOpacity.gridLines)
      ..strokeWidth = WorkoutStroke.border;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    // Draw horizontal power lines at intervals
    for (var power = 0.0; power <= maxPower * ftpValue; power += WorkoutGrid.powerLineInterval) {
      final y = size.height - (power * heightScale);
      
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );

      // Draw power labels
      textPainter.text = TextSpan(
        text: '${power.round()}w',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: WorkoutFontSizes.small,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-textPainter.width + 10, y - textPainter.height / 2));
    }
  }

  void _drawTimeGrid(Canvas canvas, Size size, double widthScale) {
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey.withOpacity(WorkoutOpacity.gridLines)
      ..strokeWidth = WorkoutStroke.border;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Draw vertical time lines at intervals
    for (var time = 0.0; time <= totalDuration; time += WorkoutGrid.timeLineInterval) {
      final x = time * widthScale;
      
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );

      // Draw time labels
      textPainter.text = TextSpan(
        text: '${(time / 60).round()}min',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: WorkoutFontSizes.small,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height + 5));
    }
  }

  void _drawCadenceIndicator(Canvas canvas, double x, double width, double height, WorkoutSegment segment) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.purple
      ..strokeWidth = WorkoutStroke.cadenceIndicator;

    final path = Path();
    
    path.moveTo(x + width / 2, height - WorkoutSizes.cadenceIndicatorHeight);
    path.lineTo(x + width / 2, height);
    
    canvas.drawPath(path, paint);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    final cadenceText = segment.cadence ?? 
                       '${segment.cadenceLow}-${segment.cadenceHigh}';
    
    textPainter.text = TextSpan(
      text: '$cadenceText rpm',
      style: TextStyle(
        color: Colors.purple,
        fontSize: WorkoutFontSizes.small,
        fontWeight: FontWeight.bold,
      ),
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        x + width / 2 - textPainter.width / 2,
        height - WorkoutSizes.cadenceIndicatorHeight - textPainter.height - 2,
      ),
    );
  }

  Color _getSegmentColor(WorkoutSegment segment) {
    switch (segment.type) {
      case SegmentType.warmup:
        return Colors.green.withOpacity(WorkoutOpacity.segmentColor);
      case SegmentType.cooldown:
        return Colors.blue.withOpacity(WorkoutOpacity.segmentColor);
      case SegmentType.intervalT:
        return segment.powerLow == segment.onPower 
            ? Colors.orange.withOpacity(WorkoutOpacity.segmentColor)  // Work interval
            : Colors.blue.withOpacity(WorkoutOpacity.segmentColor);   // Rest interval
      case SegmentType.steadyState:
        return Colors.yellow.withOpacity(WorkoutOpacity.segmentColor);
      case SegmentType.ramp:
        return Colors.purple.withOpacity(WorkoutOpacity.segmentColor);
      case SegmentType.freeRide:
        return Colors.grey.withOpacity(WorkoutOpacity.segmentColor);
      case SegmentType.maxEffort:
        return Colors.red.withOpacity(WorkoutOpacity.segmentColor);
      default:
        return Colors.grey.withOpacity(WorkoutOpacity.segmentColor);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
