import 'package:just_audio/just_audio.dart';

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

  Future<void> _playSound(String assetPath) async {
    try {
      await _player.setAsset(assetPath);
      await _player.play();
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  // Play button sound - mouse click
  Future<void> playButtonSound() async {
    await _playSound('assets/sounds/mouseclick.mp3');
  }

  // Interval countdown sound - ding ding for new segment
  Future<void> intervalCountdownSound() async {
    await _playSound('assets/sounds/dingding.mp3');
  }

  // Workout end sound - fanfare
  Future<void> workoutEndSound() async {
    await _playSound('assets/sounds/fanfare.mp3');
  }
}

// Global instance for easy access
final workoutSoundGenerator = WorkoutSoundGenerator();
