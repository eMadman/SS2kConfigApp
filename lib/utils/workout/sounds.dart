import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class WorkoutSoundGenerator {
  static final WorkoutSoundGenerator _instance = WorkoutSoundGenerator._internal();
  final AudioPlayer _player = AudioPlayer();
  
  factory WorkoutSoundGenerator() {
    return _instance;
  }

  WorkoutSoundGenerator._internal() {
    // Set up the player for low latency playback
    _player.setReleaseMode(ReleaseMode.stop);
    _player.setPlayerMode(PlayerMode.lowLatency);
  }

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
    final numSamples = (sampleRate * durationMs / 1000).round();
    final samples = Float64List(numSamples);
    
    // Generate sine wave
    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      samples[i] = sin(2 * pi * frequency * t) * volume;
    }

    // Convert to 16-bit PCM
    final pcm = Int16List(numSamples);
    for (var i = 0; i < numSamples; i++) {
      pcm[i] = (samples[i] * 32767).round().clamp(-32768, 32767);
    }

    // Create WAV header
    final header = BytesBuilder();
    
    // RIFF chunk
    header.add('RIFF'.codeUnits);  // ChunkID
    header.add(Uint32List.fromList([36 + pcm.lengthInBytes]).buffer.asUint8List());  // ChunkSize
    header.add('WAVE'.codeUnits);  // Format
    
    // fmt sub-chunk
    header.add('fmt '.codeUnits);  // Subchunk1ID
    header.add(Uint32List.fromList([16]).buffer.asUint8List());  // Subchunk1Size
    header.add(Uint16List.fromList([1]).buffer.asUint8List());  // AudioFormat (PCM)
    header.add(Uint16List.fromList([1]).buffer.asUint8List());  // NumChannels (Mono)
    header.add(Uint32List.fromList([sampleRate]).buffer.asUint8List());  // SampleRate
    header.add(Uint32List.fromList([sampleRate * 2]).buffer.asUint8List());  // ByteRate
    header.add(Uint16List.fromList([2]).buffer.asUint8List());  // BlockAlign
    header.add(Uint16List.fromList([16]).buffer.asUint8List());  // BitsPerSample
    
    // data sub-chunk
    header.add('data'.codeUnits);  // Subchunk2ID
    header.add(Uint32List.fromList([pcm.lengthInBytes]).buffer.asUint8List());  // Subchunk2Size
    
    // Combine header and PCM data
    final wavBytes = Uint8List(header.length + pcm.lengthInBytes);
    wavBytes.setAll(0, header.takeBytes());
    wavBytes.setAll(header.length, pcm.buffer.asUint8List());
    
    // Play the sound
    await _player.stop();
    final source = BytesSource(wavBytes);
    await _player.play(source);
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
