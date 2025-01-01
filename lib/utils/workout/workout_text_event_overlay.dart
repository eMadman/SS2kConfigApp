import 'package:flutter/material.dart';
import 'workout_parser.dart';
import 'workout_tts_settings.dart';
import 'workout_controller.dart';
import 'workout_constants.dart';

class WorkoutTextEventOverlay extends StatefulWidget {
  final WorkoutSegment? currentSegment;
  final int secondsIntoSegment;
  final WorkoutTTSSettings ttsSettings;
  final WorkoutController workoutController;

  const WorkoutTextEventOverlay({
    Key? key,
    required this.currentSegment,
    required this.secondsIntoSegment,
    required this.ttsSettings,
    required this.workoutController,
  }) : super(key: key);

  @override
  State<WorkoutTextEventOverlay> createState() => _WorkoutTextEventOverlayState();
}

class _WorkoutTextEventOverlayState extends State<WorkoutTextEventOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _scrollController;
  late Animation<Offset> _scrollAnimation;
  Set<String> _animatedEvents = {};  // Track which events we've already animated

  @override
  void initState() {
    super.initState();
    _scrollController = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // When animation completes, remove this event from animated set
          // so it can be animated again if it appears in a future segment
          final currentEvents = widget.currentSegment?.textEvents
              .where((event) => event.timeOffset <= widget.secondsIntoSegment)
              .map((e) => e.message) ?? {};
          _animatedEvents.removeWhere((msg) => !currentEvents.contains(msg));
        }
      });
    
    // Initialize the scroll animation with null end position
    // Will be set dynamically based on text width in build method
    _scrollAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: const Offset(-1.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _scrollController,
      curve: Curves.linear,
    ));

    // Start the animation if we have a segment
    if (widget.currentSegment != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startScrollAnimation(MediaQuery.of(context).size.width);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _startScrollAnimation(double screenWidth) {
    // Calculate duration based on screen width and desired speed
    final duration = Duration(
      milliseconds: ((screenWidth * 2) / WorkoutTextStyle.scrollSpeed * 1000).round()
    );
    
    _scrollController.duration = duration;
    _scrollController.reset();  // Ensure animation is fully reset
    _scrollController.forward();
  }

  @override
  void didUpdateWidget(WorkoutTextEventOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Clear spoken messages and animated events when segment changes
    if (widget.currentSegment != oldWidget.currentSegment) {
      widget.ttsSettings.clearSpokenMessages();
      _animatedEvents.clear();  // Reset tracking for new segment
    }
    
    if (widget.currentSegment != null) {
      // Get new events that we haven't animated yet
      final currentEvents = widget.currentSegment!.textEvents
          .where((event) => event.timeOffset <= widget.secondsIntoSegment)
          .map((e) => e.message);
      
      final newEvents = currentEvents.where((msg) => !_animatedEvents.contains(msg));
      
      if (newEvents.isNotEmpty) {
        // Add new events to our tracking set
        _animatedEvents.addAll(newEvents);
        
        // Start animation for new events
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startScrollAnimation(MediaQuery.of(context).size.width);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentSegment == null) return const SizedBox.shrink();

    // Only show the most recent text event from the current segment
    final currentEvents = widget.currentSegment!.textEvents
        .where((event) => event.timeOffset <= widget.secondsIntoSegment)
        .toList();
    
    if (currentEvents.isEmpty) return const SizedBox.shrink();

    // Get the most recent event
    final latestEvent = currentEvents.last;

    // Speak only the latest message if it hasn't been spoken yet
    widget.ttsSettings.speak(latestEvent.message);

    // Calculate text width and adjust end position
    final textPainter = TextPainter(
      text: TextSpan(
        text: latestEvent.message,
        style: TextStyle(
          fontSize: WorkoutTextStyle.scrollingText,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    final screenWidth = MediaQuery.of(context).size.width;
    final textWidth = textPainter.width;
    final endOffset = -(textWidth / screenWidth + 1.0);
    
    // Update animation with new end position
    _scrollAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset(endOffset, 0.0),
    ).animate(CurvedAnimation(
      parent: _scrollController,
      curve: Curves.linear,
    ));
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SlideTransition(
            position: _scrollAnimation,
            child: Text(
              latestEvent.message,
              style: TextStyle(
                fontSize: WorkoutTextStyle.scrollingText,
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
          ),
        ],
      ),
    );
  }
}
