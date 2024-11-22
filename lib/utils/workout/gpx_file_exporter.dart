import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'workout_controller.dart';
import 'bike_shape_generator.dart';

class GpxFileExporter {
  static Future<List<TrackPoint>> generateBikeTrackPoints(List<TrackPoint> originalPoints) async {
    final mappedPoints = <TrackPoint>[];
    
    // Extract speeds from original points
    final speeds = originalPoints.map((point) => point.speed).toList();
    
    // Generate bike shape coordinates based on speeds
    final bikePoints = await BikeShapeGenerator.generateBikeShape(speeds);
    
    // Map original data to new coordinates
    for (int i = 0; i < originalPoints.length; i++) {
      final point = originalPoints[i];
      final bikePoint = bikePoints[i];
      
      mappedPoints.add(TrackPoint(
        timestamp: point.timestamp,
        lat: bikePoint.lat,
        lon: bikePoint.lon,
        elevation: point.elevation,
        heartRate: point.heartRate,
        cadence: point.cadence,
        power: point.power,
        speed: point.speed,
      ));
    }
    
    return mappedPoints;
  }

  static Future<String> generateGpxContent(
    String workoutName,
    List<TrackPoint> trackPoints,
  ) async {
    if (trackPoints.isEmpty) {
      return ''; // Return empty string if no track points
    }

    // Generate bike shape track points based on speed and distance
    final bikeTrackPoints = await generateBikeTrackPoints(trackPoints);

    return '''<?xml version="1.0" encoding="UTF-8"?>
<gpx xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
     xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www.garmin.com/xmlschemas/GpxExtensionsv3.xsd http://www.garmin.com/xmlschemas/TrackPointExtension/v1 http://www.garmin.com/xmlschemas/TrackPointExtensionv1.xsd"
     creator="SmartSpin2k" version="1.1" 
     xmlns="http://www.topografix.com/GPX/1/1"
     xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1"
     xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3">
 <metadata>
  <time>${bikeTrackPoints.first.timestamp.toIso8601String()}</time>
 </metadata>
 <trk>
  <name>$workoutName</name>
  <type>VirtualRide</type>
  <trkseg>
${bikeTrackPoints.map((point) => '''   <trkpt lat="${point.lat}" lon="${point.lon}">
    <ele>${point.elevation}</ele>
    <time>${point.timestamp.toIso8601String()}</time>
    <extensions>
     <power>${point.power}</power>
     <gpxtpx:TrackPointExtension>
      <gpxtpx:hr>${point.heartRate}</gpxtpx:hr>
      <gpxtpx:cad>${point.cadence}</gpxtpx:cad>
     </gpxtpx:TrackPointExtension>
    </extensions>
   </trkpt>''').join('\n')}
  </trkseg>
 </trk>
</gpx>''';
  }

  static Future<void> showExportDialog(BuildContext context, WorkoutController workoutController, String? currentWorkoutContent) async {
    final bool? shouldExport = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Export Workout'),
          content: const Text('Would you like to export your workout as a GPX file?'),
          actions: <Widget>[
            TextButton(
              child: const Text('NO'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('YES'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldExport == true) {
      await exportGpxFile(context, workoutController);
    }

    // Reset workout position to beginning
    if (currentWorkoutContent != null) {
      workoutController.loadWorkout(currentWorkoutContent);
    }
  }

  static Future<void> exportGpxFile(BuildContext context, WorkoutController workoutController) async {
    try {
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'workout_${timestamp}.gpx';
      
      // Generate GPX content using collected track points
      final gpxContent = await generateGpxContent(
        workoutController.workoutName ?? 'Unnamed Workout',
        workoutController.trackPoints,
      );

      if (gpxContent.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No workout data to export'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get the appropriate directory based on platform
      final Directory appDir;
      if (Platform.isIOS) {
        appDir = await getApplicationDocumentsDirectory();
      } else {
        appDir = await getApplicationDocumentsDirectory();
      }

      // Create workouts directory if it doesn't exist
      final workoutsDir = Directory('${appDir.path}${Platform.pathSeparator}workouts');
      if (!await workoutsDir.exists()) {
        await workoutsDir.create(recursive: true);
      }

      // Save the file
      final file = File('${workoutsDir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsString(gpxContent);

      if (context.mounted) {
        final bool? shouldShare = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Workout Exported'),
              content: Text('File saved to: ${file.path}\n\nWould you like to share it now?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('NO'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: const Text('YES'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        );

        if (shouldShare == true) {
          try {
            await Share.shareXFiles([XFile(file.path)]);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to share file: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export workout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
