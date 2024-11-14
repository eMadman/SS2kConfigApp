import 'package:flutter/material.dart';
import 'dart:async';
import '../bledata.dart';
import 'workout_parser.dart';
import 'workout_constants.dart';

class WorkoutController extends ChangeNotifier {
  List<WorkoutSegment> segments = [];
  String? workoutName;
  double maxPower = 0;
  double totalDuration = 0;
  double ftpValue = 200; // Default FTP value
  bool isPlaying = false;
  double progressPosition = 0;
  Timer? progressTimer;
  List<double> actualPowerPoints = [];
  int elapsedSeconds = 0;
  int currentSegmentTimeRemaining = 0;
  final BLEData bleData;

  WorkoutController(this.bleData);

  void togglePlayPause() {
    isPlaying = !isPlaying;
    if (isPlaying) {
      startProgress();
      actualPowerPoints = []; // Reset power points when starting
      elapsedSeconds = 0;
    } else {
      progressTimer?.cancel();
    }
    notifyListeners();
  }

  void skipToNextSegment() {
    if (segments.isEmpty || !isPlaying) return;

    double currentTime = progressPosition * totalDuration;
    double elapsedTime = 0;
    
    for (int i = 0; i < segments.length; i++) {
      if (currentTime >= elapsedTime && currentTime < elapsedTime + segments[i].duration) {
        // If this is the last segment, stop the workout
        if (i == segments.length - 1) {
          progressPosition = 1.0;
          isPlaying = false;
          progressTimer?.cancel();
          notifyListeners();
          return;
        }
        
        // Skip to the start of the next segment
        progressPosition = (elapsedTime + segments[i].duration) / totalDuration;
        notifyListeners();
        return;
      }
      elapsedTime += segments[i].duration;
    }
  }

  void loadWorkout(String xmlContent) {
    try {
      final workoutData = WorkoutParser.parseZwoFile(xmlContent);
      
      double maxPowerTemp = 0;
      double totalDurationTemp = 0;
      
      for (var segment in workoutData.segments) {
        if (segment.isRamp) {
          maxPowerTemp = [maxPowerTemp, segment.powerLow, segment.powerHigh]
              .reduce((curr, next) => curr > next ? curr : next);
        } else {
          maxPowerTemp = [maxPowerTemp, segment.powerLow]
              .reduce((curr, next) => curr > next ? curr : next);
        }
        totalDurationTemp += segment.duration;
      }

      maxPowerTemp *= 1.1;
      
      segments = workoutData.segments;
      workoutName = workoutData.name;
      maxPower = maxPowerTemp;
      totalDuration = totalDurationTemp;
      progressPosition = 0;
      actualPowerPoints = [];
      elapsedSeconds = 0;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  void startProgress() {
    progressTimer?.cancel();
    progressTimer = Timer.periodic(WorkoutDurations.progressUpdateInterval, (timer) {
      progressPosition += WorkoutDurations.progressUpdateInterval.inMilliseconds / (totalDuration * 1000);
      elapsedSeconds = (progressPosition * totalDuration).round();
      
      // Record actual power point
      final currentPower = bleData.ftmsData.watts / ftpValue;
      actualPowerPoints.add(currentPower);
      
      if (progressPosition >= 1.0) {
        progressPosition = 0;
        isPlaying = false;
        timer.cancel();
        notifyListeners();
        return;
      }

      // Update target watts and remaining time based on current position
      if (segments.isNotEmpty) {
        double currentTime = progressPosition * totalDuration;
        double elapsedTime = 0;
        
        for (var segment in segments) {
          if (currentTime >= elapsedTime && currentTime < elapsedTime + segment.duration) {
            double segmentProgress = (currentTime - elapsedTime) / segment.duration;
            double targetPower;
            
            if (segment.isRamp) {
              targetPower = segment.powerLow + (segment.powerHigh - segment.powerLow) * segmentProgress;
            } else {
              targetPower = segment.powerLow;
            }
            
            bleData.ftmsData.targetERG = (targetPower * ftpValue).round();
            currentSegmentTimeRemaining = ((elapsedTime + segment.duration) - currentTime).round();
            break;
          }
          elapsedTime += segment.duration;
        }
      }
      notifyListeners();
    });
  }

  void updateFTP(double? newValue) {
    if (newValue != null) {
      ftpValue = newValue;
      notifyListeners();
    }
  }

  String formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    progressTimer?.cancel();
    super.dispose();
  }
}
