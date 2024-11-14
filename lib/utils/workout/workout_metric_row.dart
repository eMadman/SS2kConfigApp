import 'package:flutter/material.dart';
import 'dart:math';
import 'workout_constants.dart';

class WorkoutMetricRow extends StatelessWidget {
  final List<WorkoutMetric> metrics;

  const WorkoutMetricRow({
    Key? key,
    required this.metrics,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate total width of all metrics
        double totalWidth = metrics.fold(0.0, (sum, metric) {
          return sum + _calculateMetricWidth(metric.value) + (2 * WorkoutPadding.metricHorizontal);
        });

        // If total width is less than available width, center the row
        if (totalWidth <= constraints.maxWidth) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: metrics.map((metric) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: WorkoutPadding.metricHorizontal),
                child: MetricBox(metric: metric),
              );
            }).toList(),
          );
        }

        // Otherwise, use scrollable row
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: metrics.map((metric) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: WorkoutPadding.metricHorizontal),
                child: MetricBox(metric: metric),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  double _calculateMetricWidth(String value) {
    double width = value.length * 20.0;
    return width.clamp(MetricBox.minWidth, MetricBox.maxWidth);
  }
}

class MetricBox extends StatelessWidget {
  final WorkoutMetric metric;
  static const double minWidth = 100.0;
  static const double maxWidth = 160.0;
  static const double height = 80.0;
  static const double baseFontSize = 28.0;
  static const double minFontSize = 16.0;

  const MetricBox({
    Key? key,
    required this.metric,
  }) : super(key: key);

  double _calculateFontSize(String text, double boxWidth) {
    // Start with base font size
    double fontSize = baseFontSize;
    
    // Estimate text width (rough approximation)
    double estimatedWidth = text.length * (fontSize * 0.6);
    
    // If text might overflow, scale down the font size
    if (estimatedWidth > boxWidth - 20) { // 20 is padding
      fontSize = min(
        baseFontSize,
        max(
          minFontSize,
          (boxWidth - 20) / (text.length * 0.6)
        )
      );
    }
    
    return fontSize;
  }

  double _calculateBoxWidth(String value) {
    // Calculate dynamic width based on content length
    double width = value.length * 20.0; // Base calculation
    return width.clamp(minWidth, maxWidth);
  }

  @override
  Widget build(BuildContext context) {
    final boxWidth = _calculateBoxWidth(metric.value);
    final valueFontSize = _calculateFontSize(metric.value, boxWidth);

    return Container(
      width: boxWidth,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            metric.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.value,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          if (metric.unit != null) ...[
            const SizedBox(height: 2),
            Text(
              metric.unit!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class WorkoutMetric {
  final String label;
  final String value;
  final String? unit;

  const WorkoutMetric({
    required this.label,
    required this.value,
    this.unit,
  });

  factory WorkoutMetric.power({required int watts}) {
    return WorkoutMetric(
      label: 'Power',
      value: watts.toString(),
      unit: 'W',
    );
  }

  factory WorkoutMetric.heartRate({required int bpm}) {
    return WorkoutMetric(
      label: 'Heart Rate',
      value: bpm.toString(),
      unit: 'BPM',
    );
  }

  factory WorkoutMetric.cadence({required int rpm}) {
    return WorkoutMetric(
      label: 'Cadence',
      value: rpm.toString(),
      unit: 'RPM',
    );
  }

  factory WorkoutMetric.elapsedTime({required int seconds}) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    
    return WorkoutMetric(
      label: 'Elapsed Time',
      value: '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}',
    );
  }
}
