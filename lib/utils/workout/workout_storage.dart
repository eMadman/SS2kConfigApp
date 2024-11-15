import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WorkoutStorage {
  static const String _ftpKey = 'workout_ftp_value';
  static const String _workoutStateKey = 'workout_state';
  static const String _workoutContentKey = 'workout_content';
  static const String _elapsedSecondsKey = 'workout_elapsed_seconds';
  static const String _isPlayingKey = 'workout_is_playing';
  static const String _savedWorkoutsKey = 'saved_workouts';
  static const String _workoutThumbnailPrefix = 'workout_thumbnail_';

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

  // Save a workout to the library
  static Future<void> saveWorkoutToLibrary({
    required String workoutContent,
    required String workoutName,
    required String thumbnailData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing workouts
    final workouts = await getSavedWorkouts();
    
    // Add new workout
    workouts.add({
      'name': workoutName,
      'content': workoutContent,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    // Save updated workout list
    await prefs.setString(_savedWorkoutsKey, jsonEncode(workouts));
    
    // Save thumbnail separately (using workout name as key)
    await prefs.setString('$_workoutThumbnailPrefix$workoutName', thumbnailData);
  }

  // Get list of saved workouts
  static Future<List<Map<String, dynamic>>> getSavedWorkouts() async {
    final prefs = await SharedPreferences.getInstance();
    final workoutsJson = prefs.getString(_savedWorkoutsKey);
    
    if (workoutsJson == null) return [];
    
    final List<dynamic> decoded = jsonDecode(workoutsJson);
    return decoded.cast<Map<String, dynamic>>();
  }

  // Get thumbnail for a workout
  static Future<String?> getWorkoutThumbnail(String workoutName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_workoutThumbnailPrefix$workoutName');
  }

  // Delete a workout from the library
  static Future<void> deleteWorkout(String workoutName) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing workouts
    final workouts = await getSavedWorkouts();
    
    // Remove workout with matching name
    workouts.removeWhere((workout) => workout['name'] == workoutName);
    
    // Save updated workout list
    await prefs.setString(_savedWorkoutsKey, jsonEncode(workouts));
    
    // Remove thumbnail
    await prefs.remove('$_workoutThumbnailPrefix$workoutName');
  }
}
