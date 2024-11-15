import 'package:flutter/material.dart';
import 'dart:async';
import '../bledata.dart';
import '../ftmsControlPoint.dart';
import 'workout_parser.dart';
import 'workout_constants.dart';
import 'sounds.dart';

class WorkoutController extends ChangeNotifier {
  List<WorkoutSegment> segments = [];
  String? workoutName;
  double maxPower = 0;
  double totalDuration = 0;
  double ftpValue = 200; // Default FTP value
  bool isPlaying = false;
  double progressPosition = 0;
  Timer? progressTimer;
  Map<int, double> actualPowerPoints = {}; // Map time index to power value
  int elapsedSeconds = 0;
  int currentSegmentTimeRemaining = 0;
  final BLEData bleData;
  bool _isCountingDown = false;

  WorkoutController(this.bleData) {
    // Reset simulation parameters on initialization
    _resetSimulationParameters();
  }

  // Helper method to reset simulation parameters
  Future<void> _resetSimulationParameters() async {
    if (bleData.ftmsControlPointCharacteristic != null) {
      try {
        await FTMSControlPoint.writeIndoorBikeSimulation(
          bleData.ftmsControlPointCharacteristic!,
          windSpeed: 0,
          grade: 0,
          crr: 0,
          cw: 0,
        );
      } catch (e) {
        print('Error resetting simulation parameters: $e');
      }
    }
  }

  void togglePlayPause() {
    isPlaying = !isPlaying;
    if (isPlaying) {
      startProgress();
      actualPowerPoints = {}; // Reset power points when starting
      elapsedSeconds = 0;
    } else {
      progressTimer?.cancel();
      // Reset simulation parameters when stopping
      _resetSimulationParameters();
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
          // Play workout end sound and reset simulation parameters
          workoutSoundGenerator.workoutEndSound();
          _resetSimulationParameters();
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
      actualPowerPoints = {};
      elapsedSeconds = 0;
      
      // Reset simulation parameters when loading new workout
      _resetSimulationParameters();
      
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
      
      // Store power value at current time index
      actualPowerPoints[elapsedSeconds] = bleData.ftmsData.watts.toDouble();
      
      if (progressPosition >= 1.0) {
        progressPosition = 0;
        isPlaying = false;
        timer.cancel();
        // Play workout end sound and reset simulation parameters
        workoutSoundGenerator.workoutEndSound();
        _resetSimulationParameters();
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

            // Play countdown sound when approaching next segment
            if (currentSegmentTimeRemaining <= 3 && !_isCountingDown) {
              _isCountingDown = true;
              workoutSoundGenerator.intervalCountdownSound();
            } else if (currentSegmentTimeRemaining > 3) {
              _isCountingDown = false;
            }
            
            break;
          }
          elapsedTime += segment.duration;
        }
      }
      notifyListeners();
    });
  }

  // Get power points as a list up to current time
  List<double> getPowerPointsUpToNow() {
    final maxSeconds = elapsedSeconds;
    List<double> points = List.filled(maxSeconds + 1, 0);
    
    for (int i = 0; i <= maxSeconds; i++) {
      // Use the actual power value if we have it, otherwise interpolate between known points
      if (actualPowerPoints.containsKey(i)) {
        points[i] = actualPowerPoints[i]!;
      } else {
        // Find nearest known points before and after
        int? beforeTime = actualPowerPoints.keys
            .where((time) => time < i)
            .fold<int?>(null, (max, time) => max == null || time > max ? time : max);
        int? afterTime = actualPowerPoints.keys
            .where((time) => time > i)
            .fold<int?>(null, (min, time) => min == null || time < min ? time : min);
            
        if (beforeTime != null && afterTime != null) {
          // Interpolate between known points
          double beforeValue = actualPowerPoints[beforeTime]!;
          double afterValue = actualPowerPoints[afterTime]!;
          double ratio = (i - beforeTime) / (afterTime - beforeTime);
          points[i] = beforeValue + (afterValue - beforeValue) * ratio;
        } else if (beforeTime != null) {
          // Use last known value
          points[i] = actualPowerPoints[beforeTime]!;
        } else if (afterTime != null) {
          // Use next known value
          points[i] = actualPowerPoints[afterTime]!;
        } else {
          // No known values, use current power
          points[i] = bleData.ftmsData.watts.toDouble();
        }
      }
    }
    
    return points;
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
