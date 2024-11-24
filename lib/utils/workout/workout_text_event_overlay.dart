import 'package:flutter/material.dart';
import 'workout_constants.dart';
import 'workout_parser.dart';

class WorkoutTextEventOverlay extends StatelessWidget {
  final WorkoutSegment? currentSegment;
  final int secondsIntoSegment;
  final Animation<double> fadeAnimation;

  const WorkoutTextEventOverlay({
    Key? key,
    required this.currentSegment,
    required this.secondsIntoSegment,
    required this.fadeAnimation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (currentSegment == null) return const SizedBox.shrink();

    final visibleEvents = currentSegment!.getVisibleTextEventsAt(secondsIntoSegment);
    if (visibleEvents.isEmpty) return const SizedBox.shrink();

    return FadeTransition(
      opacity: fadeAnimation,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: EdgeInsets.only(
            top: WorkoutSpacing.medium * 4,
            left: WorkoutPadding.standard,
            right: WorkoutPadding.standard,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: visibleEvents.map((event) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: WorkoutSpacing.xsmall),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: WorkoutPadding.standard,
                    vertical: WorkoutPadding.small,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Opacity(
                    opacity: event.getOpacityAt(secondsIntoSegment),
                    child: Text(
                      event.message,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
