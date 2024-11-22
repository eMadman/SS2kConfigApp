import 'dart:io';
import 'package:fit_tool/fit_tool.dart';
import 'package:gpx/gpx.dart';

class GpxToFitConverter {
  /// Converts a GPX file to FIT format and returns the path to the new FIT file
  static Future<String> convertGpxToFit(String gpxFilePath) async {
    // Read GPX file
    final gpxFile = File(gpxFilePath);
    final gpxString = await gpxFile.readAsString();
    final xmlGpx = GpxReader().fromString(gpxString);

    // Create FIT file builder
    final builder = FitFileBuilder(autoDefine: true, minStringSize: 50);

    // Add File ID message
    final fileIdMessage = FileIdMessage()
      ..type = FileType.activity
      ..manufacturer = Manufacturer.development.value
      ..product = 0
      ..timeCreated = DateTime.now().millisecondsSinceEpoch
      ..serialNumber = 0x12345678;
    builder.add(fileIdMessage);

    // Add start event
    final startTimestamp = DateTime.now().millisecondsSinceEpoch;
    final eventMessage = EventMessage()
      ..event = Event.timer
      ..eventType = EventType.start
      ..timestamp = startTimestamp;
    builder.add(eventMessage);

    // Process track points
    final records = <RecordMessage>[];
    var timestamp = startTimestamp;
    
    if (xmlGpx.trks.isNotEmpty && xmlGpx.trks[0].trksegs.isNotEmpty) {
      for (var trackPoint in xmlGpx.trks[0].trksegs[0].trkpts) {
        timestamp += 1000; // 1 second intervals
        records.add(RecordMessage()
          ..timestamp = timestamp
          ..positionLong = trackPoint.lon
          ..positionLat = trackPoint.lat
          ..altitude = trackPoint.ele);
      }
      builder.addAll(records);

      // Add Lap message
      final elapsedTime = (timestamp - startTimestamp).toDouble();
      final lapMessage = LapMessage()
        ..timestamp = timestamp
        ..startTime = startTimestamp
        ..totalElapsedTime = elapsedTime
        ..totalTimerTime = elapsedTime;
      builder.add(lapMessage);

      // Add Session message
      final sessionMessage = SessionMessage()
        ..timestamp = timestamp
        ..startTime = startTimestamp
        ..totalElapsedTime = elapsedTime
        ..totalTimerTime = elapsedTime
        ..sport = Sport.cycling
        ..subSport = SubSport.exercise
        ..firstLapIndex = 0
        ..numLaps = 1;
      builder.add(sessionMessage);

      // Build and save FIT file
      final fitFile = builder.build();
      final fitFilePath = gpxFilePath.replaceAll('.gpx', '.fit');
      final outFile = File(fitFilePath);
      await outFile.writeAsBytes(fitFile.toBytes());

      return fitFilePath;
    } else {
      throw Exception('No track points found in GPX file');
    }
  }

  /// Converts GPX to FIT, deletes the GPX file, and returns the FIT file path
  static Future<String> convertAndCleanup(String gpxFilePath) async {
    try {
      final fitFilePath = await convertGpxToFit(gpxFilePath);
      // Delete the original GPX file
      final gpxFile = File(gpxFilePath);
      if (await gpxFile.exists()) {
        await gpxFile.delete();
      }
      return fitFilePath;
    } catch (e) {
      throw Exception('Failed to convert GPX to FIT: $e');
    }
  }
}
