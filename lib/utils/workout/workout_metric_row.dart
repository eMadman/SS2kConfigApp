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
    double width = value.length * WorkoutSizes.metricCharacterWidth;
    return width.clamp(WorkoutSizes.metricBoxMinWidth, WorkoutSizes.metricBoxMaxWidth);
  }
}

class MetricBox extends StatelessWidget {
  final WorkoutMetric metric;

  const MetricBox({
    Key? key,
    required this.metric,
  }) : super(key: key);

  double _calculateFontSize(String text, double boxWidth) {
    // Start with base font size
    double fontSize = WorkoutFontSizes.metricValueBase;
    
    // Estimate text width (rough approximation)
    double estimatedWidth = text.length * (fontSize * 0.6);
    
    // If text might overflow, scale down the font size
    if (estimatedWidth > boxWidth - WorkoutPadding.metricBoxContent) {
      fontSize = min(
        WorkoutFontSizes.metricValueBase,
        max(
          WorkoutFontSizes.metricValueMin,
          (boxWidth - WorkoutPadding.metricBoxContent) / (text.length * 0.6)
        )
      );
    }
    
    return fontSize;
  }

  double _calculateBoxWidth(String value) {
    double width = value.length * WorkoutSizes.metricCharacterWidth;
    return width.clamp(WorkoutSizes.metricBoxMinWidth, WorkoutSizes.metricBoxMaxWidth);
  }

  @override
  Widget build(BuildContext context) {
    final boxWidth = _calculateBoxWidth(metric.value);
    final valueFontSize = _calculateFontSize(metric.value, boxWidth);

    return Container(
      width: boxWidth,
      height: WorkoutSizes.metricBoxHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(WorkoutSizes.metricBoxBorderRadius),
        boxShadow: [WorkoutShadows.metricBox],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            metric.label,
            style: TextStyle(
              fontSize: WorkoutFontSizes.metricLabel,
              fontWeight: WorkoutFontWeights.metricLabel,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          SizedBox(height: WorkoutSpacing.metricLabelValue),
          Text(
            metric.value,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: WorkoutFontWeights.metricValue,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          if (metric.unit != null) ...[
            SizedBox(height: WorkoutSpacing.metricValueUnit),
            Text(
              metric.unit!,
              style: TextStyle(
                fontSize: WorkoutFontSizes.metricUnit,
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
