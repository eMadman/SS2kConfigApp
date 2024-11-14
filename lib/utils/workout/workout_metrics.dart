import 'package:flutter/material.dart';
import '../bledata.dart';
import '../../widgets/metric_card.dart';
import 'workout_constants.dart';

class WorkoutMetrics extends StatelessWidget {
  final BLEData bleData;
  final Animation<double> fadeAnimation;

  const WorkoutMetrics({
    Key? key,
    required this.bleData,
    required this.fadeAnimation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: ReverseAnimation(fadeAnimation),
      child: Card(
        margin: EdgeInsets.all(WorkoutPadding.small),
        child: Padding(
          padding: EdgeInsets.all(WorkoutPadding.standard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Real-Time Metrics',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: WorkoutSpacing.xsmall),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: WorkoutPadding.metricHorizontal),
                      child: MetricBox(
                        value: bleData.ftmsData.watts.toString(),
                        label: 'Current Power',
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: WorkoutPadding.metricHorizontal),
                      child: MetricBox(
                        value: bleData.ftmsData.targetERG.toString(),
                        label: 'Target Power',
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: WorkoutPadding.metricHorizontal),
                      child: MetricBox(
                        value: bleData.ftmsData.cadence.toString(),
                        label: 'Cadence',
                      ),
                    ),
                    if (bleData.ftmsData.heartRate != 0)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: WorkoutPadding.metricHorizontal),
                        child: MetricBox(
                          value: bleData.ftmsData.heartRate.toString(),
                          label: 'Heart Rate',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
