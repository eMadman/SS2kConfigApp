import 'package:flutter/material.dart';
import '../bledata.dart';
import 'workout_constants.dart';
import 'workout_metric_row.dart';

class WorkoutMetrics extends StatelessWidget {
  final BLEData bleData;
  final Animation<double> fadeAnimation;
  final int elapsedTime;
  final int timeToNextSegment;

  const WorkoutMetrics({
    Key? key,
    required this.bleData,
    required this.fadeAnimation,
    required this.elapsedTime,
    required this.timeToNextSegment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final metrics = [
      WorkoutMetric.elapsedTime(seconds: elapsedTime),
      WorkoutMetric(
        label: 'Next Interval',
        value: _formatDuration(timeToNextSegment),
      ),
      WorkoutMetric.power(watts: bleData.ftmsData.watts),
      WorkoutMetric(
        label: 'Target',
        value: bleData.ftmsData.targetERG.toString(),
        unit: 'W',
      ),
      WorkoutMetric.cadence(rpm: bleData.ftmsData.cadence),
      if (bleData.ftmsData.heartRate != 0) WorkoutMetric.heartRate(bpm: bleData.ftmsData.heartRate),
    ];

    return FadeTransition(
      opacity: ReverseAnimation(fadeAnimation),
      child: Card(
        margin: EdgeInsets.all(WorkoutPadding.small),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WorkoutMetricRow(metrics: metrics),
        ]),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
