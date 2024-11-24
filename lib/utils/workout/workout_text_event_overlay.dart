import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'workout_constants.dart';
import 'workout_parser.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class WorkoutTextEventOverlay extends StatefulWidget {
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
  State<WorkoutTextEventOverlay> createState() => _WorkoutTextEventOverlayState();
}

class _WorkoutTextEventOverlayState extends State<WorkoutTextEventOverlay> {
  late FlutterTts flutterTts;
  Set<String> spokenMessages = {};
  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("en-US");
    if (isIOS) {
      await flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.ambient,
          [
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt);
    }
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
  }

  Future<void> _speakMessage(String message) async {
    if (!spokenMessages.contains(message)) {
      await flutterTts.speak(message);
      spokenMessages.add(message);
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  void didUpdateWidget(WorkoutTextEventOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Clear spoken messages when segment changes
    if (widget.currentSegment != oldWidget.currentSegment) {
      spokenMessages.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentSegment == null) return const SizedBox.shrink();

    final visibleEvents = widget.currentSegment!.getVisibleTextEventsAt(widget.secondsIntoSegment);
    if (visibleEvents.isEmpty) return const SizedBox.shrink();

    // Speak all visible messages that haven't been spoken yet
    for (final event in visibleEvents) {
      _speakMessage(event.message);
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
                  color: const Color.fromARGB(255, 51, 50, 50),
                  shadows: [
                    Shadow(
                      blurRadius: 3.0,
                      color: Colors.black.withOpacity(0.75),
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
