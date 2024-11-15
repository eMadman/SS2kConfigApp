import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WorkoutStorage {
  static const String _ftpKey = 'workout_ftp_value';
  static const String _workoutStateKey = 'workout_state';
  static const String _workoutContentKey = 'workout_content';
  static const String _elapsedSecondsKey = 'workout_elapsed_seconds';
  static const String _isPlayingKey = 'workout_is_playing';

  // Save FTP value
  static Future<void> saveFTP(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_ftpKey, value);
  }

  // Load FTP value
  static Future<double> loadFTP() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_ftpKey) ?? 200.0; // Default FTP value
  }

  // Save workout state
  static Future<void> saveWorkoutState({
    required String? workoutContent,
    required double progressPosition,
    required int elapsedSeconds,
    required bool isPlaying,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (workoutContent != null) {
      await prefs.setString(_workoutContentKey, workoutContent);
    }
    
    final stateJson = jsonEncode({
      'progressPosition': progressPosition,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    await prefs.setString(_workoutStateKey, stateJson);
    await prefs.setInt(_elapsedSecondsKey, elapsedSeconds);
    await prefs.setBool(_isPlayingKey, isPlaying);
  }

  // Load workout state
  static Future<Map<String, dynamic>> loadWorkoutState() async {
    final prefs = await SharedPreferences.getInstance();
    
    final workoutContent = prefs.getString(_workoutContentKey);
    final stateJson = prefs.getString(_workoutStateKey);
    final elapsedSeconds = prefs.getInt(_elapsedSecondsKey) ?? 0;
    final wasPlaying = prefs.getBool(_isPlayingKey) ?? false;
    
    double progressPosition = 0.0;
    
    if (stateJson != null) {
      final state = jsonDecode(stateJson) as Map<String, dynamic>;
      final savedTimestamp = state['timestamp'] as int;
      final savedProgress = state['progressPosition'] as double;
      
      if (wasPlaying) {
        // Calculate time elapsed since last save
        final elapsedMillis = DateTime.now().millisecondsSinceEpoch - savedTimestamp;
        final elapsedMinutes = elapsedMillis / 60000; // Convert to minutes
        
        // Adjust progress based on elapsed time
        progressPosition = savedProgress + (elapsedMinutes / 60); // Assuming workout duration is in seconds
        progressPosition = progressPosition.clamp(0.0, 1.0);
      } else {
        progressPosition = savedProgress;
      }
    }
    
    return {
      'workoutContent': workoutContent,
      'progressPosition': progressPosition,
      'elapsedSeconds': elapsedSeconds,
      'wasPlaying': wasPlaying,
    };
  }

  // Clear workout state
  static Future<void> clearWorkoutState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_workoutStateKey);
    await prefs.remove(_workoutContentKey);
    await prefs.remove(_elapsedSecondsKey);
    await prefs.remove(_isPlayingKey);
  }
}
