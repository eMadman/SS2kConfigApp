import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class WorkoutSoundGenerator {
  static final WorkoutSoundGenerator _instance = WorkoutSoundGenerator._internal();
  final AudioPlayer _player = AudioPlayer();
  
  factory WorkoutSoundGenerator() {
    return _instance;
  }

  WorkoutSoundGenerator._internal();

  Future<void> dispose() async {
    await _player.dispose();
  }

  // Generate a beep sound at a specific frequency
  Future<void> _playBeep({
    required double frequency,
    required int durationMs,
    double volume = 0.5
  }) async {
    const sampleRate = 44100;
    final samples = List<int>.filled(sampleRate * durationMs ~/ 1000, 0);
    
    for (var i = 0; i < samples.length; i++) {
      final t = i / sampleRate;
      final wave = sin(2 * pi * frequency * t);
      // Convert to 16-bit PCM
      samples[i] = (wave * volume * 32767).toInt();
    }

    // Create a source from the samples
    final bytes = samples.map((s) => [s & 0xFF, (s >> 8) & 0xFF]).expand((e) => e).toList();
    final blob = BytesSource(Uint8List.fromList(bytes));
    
    await _player.play(blob);
  }

  // Play button sound - short, distinct beep
  Future<void> playButtonSound() async {
    await _playBeep(
      frequency: 880.0, // A5 note
      durationMs: 100,
      volume: 0.5
    );
  }

  // Interval countdown sound - "tick, tick, tick, ding!"
  Future<void> intervalCountdownSound() async {
    // Play three ticks
    for (var i = 0; i < 3; i++) {
      await _playBeep(
        frequency: 440.0, // A4 note
        durationMs: 100,
        volume: 0.3
      );
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    // Play final ding
    await _playBeep(
      frequency: 880.0, // A5 note
      durationMs: 200,
      volume: 0.5
    );
  }

  // Workout end sound - triumphant trumpet-like sound
  Future<void> workoutEndSound() async {
    final notes = [523.25, 659.25, 783.99, 1046.50]; // C5, E5, G5, C6
    final durations = [200, 200, 200, 400];
    
    for (var i = 0; i < notes.length; i++) {
      await _playBeep(
        frequency: notes[i],
        durationMs: durations[i],
        volume: 0.4
      );
      
      if (i < notes.length - 1) {
        await Future.delayed(Duration(milliseconds: durations[i] ~/ 2));
      }
    }
  }
}

// Global instance for easy access
final workoutSoundGenerator = WorkoutSoundGenerator();
