import 'package:flutter/material.dart';
import 'workout_parser.dart';
import 'workout_tts_settings.dart';
import 'workout_controller.dart';

class WorkoutTextEventOverlay extends StatefulWidget {
  final WorkoutSegment? currentSegment;
  final int secondsIntoSegment;
  final Animation<double> fadeAnimation;
  final WorkoutTTSSettings ttsSettings;
  final WorkoutController workoutController;

  const WorkoutTextEventOverlay({
    Key? key,
    required this.currentSegment,
    required this.secondsIntoSegment,
    required this.fadeAnimation,
    required this.ttsSettings,
    required this.workoutController,
  }) : super(key: key);

  @override
  State<WorkoutTextEventOverlay> createState() => _WorkoutTextEventOverlayState();
}

class _WorkoutTextEventOverlayState extends State<WorkoutTextEventOverlay> {
  @override
  void didUpdateWidget(WorkoutTextEventOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Clear spoken messages when segment changes
    if (widget.currentSegment != oldWidget.currentSegment) {
      widget.ttsSettings.clearSpokenMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentSegment == null) return const SizedBox.shrink();

    final visibleEvents = widget.currentSegment!.getVisibleTextEventsAt(widget.secondsIntoSegment);
    if (visibleEvents.isEmpty) return const SizedBox.shrink();

    // Speak all visible messages that haven't been spoken yet
    for (final event in visibleEvents) {
      widget.ttsSettings.speak(event.message);
    }

    return FadeTransition(
      opacity: widget.fadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: visibleEvents.map((event) {
            return Opacity(
              opacity: event.getOpacityAt(widget.secondsIntoSegment),
              child: Text(
                event.message,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 3.0,
                      color: const Color.fromARGB(255, 48, 47, 47).withOpacity(0.75),
                      offset: const Offset(1.0, 1.0),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
