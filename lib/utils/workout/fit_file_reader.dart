import 'dart:io';
import 'package:fit_tool/fit_tool.dart';
import 'package:path_provider/path_provider.dart';

class ActivitySummary {
  final String name;
  final DateTime timestamp;
  final Duration duration;
  final int averagePower;
  final int averageCadence;
  final int averageHeartRate;
  final String filePath;

  ActivitySummary({
    required this.name,
    required this.timestamp,
    required this.duration,
    required this.averagePower,
    required this.averageCadence,
    required this.averageHeartRate,
    required this.filePath,
  });
}

class FitFileReader {
  static Future<List<ActivitySummary>> getCompletedActivities() async {
    final List<ActivitySummary> activities = [];
    
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory workoutsDir = Directory('${appDir.path}${Platform.pathSeparator}workouts');
      
      if (!await workoutsDir.exists()) {
        return activities;
      }

      final List<FileSystemEntity> files = await workoutsDir
          .list()
          .where((entity) => entity.path.toLowerCase().endsWith('.fit'))
          .toList();

      for (final file in files) {
        try {
          final bytes = await File(file.path).readAsBytes();
          final fitFile = FitFile.fromBytes(bytes);
          
          int totalPower = 0;
          int totalCadence = 0;
          int totalHeartRate = 0;
          int recordCount = 0;
          DateTime? startTime;
          DateTime? endTime;

          for (final record in fitFile.records) {
            if (record.message is RecordMessage) {
              final recordMessage = record.message as RecordMessage;
              if (recordMessage.power != null) totalPower += recordMessage.power!;
              if (recordMessage.cadence != null) totalCadence += recordMessage.cadence!;
              if (recordMessage.heartRate != null) totalHeartRate += recordMessage.heartRate!;
              recordCount++;
            } else if (record.message is SessionMessage) {
              final session = record.message as SessionMessage;
              startTime = DateTime.fromMillisecondsSinceEpoch(session.startTime!);
              endTime = DateTime.fromMillisecondsSinceEpoch(session.timestamp!);
            }
          }

          if (recordCount > 0 && startTime != null && endTime != null) {
            activities.add(ActivitySummary(
              name: file.path.split(Platform.pathSeparator).last.replaceAll('.fit', ''),
              timestamp: startTime,
              duration: endTime.difference(startTime),
              averagePower: totalPower ~/ recordCount,
              averageCadence: totalCadence ~/ recordCount,
              averageHeartRate: totalHeartRate ~/ recordCount,
              filePath: file.path,
            ));
          }
        } catch (e) {
          print('Error reading FIT file ${file.path}: $e');
        }
      }

      // Sort activities by date, most recent first
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      return activities;
    } catch (e) {
      print('Error reading completed activities: $e');
      return activities;
    }
  }
}