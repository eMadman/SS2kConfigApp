import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'workout_controller.dart';

class GpxFileExporter {
  // Eau Claire, WI coordinates
  static const double centerLat = 44.8113;
  static const double centerLon = -91.4985;
  
  // Bike dimensions (in degrees)
  static const double wheelRadius = 0.05; // Larger wheels
  static const double frameLength = 0.3; // Total frame length
  static const double frameHeight = 0.2; // Total frame height

  // Power output constants for a 150lb rider
  static const double targetWattsFor20mph = 165.0; // Average watts needed for 20mph
  static const double targetDistanceKm = 32.19; // Distance at 20mph for 1 hour

  // Constants for coordinate calculations
  static const double metersPerDegreeLatitude = 111320.0; // At equator

  static double _getMetersPerDegreeLongitude() {
    return metersPerDegreeLatitude * cos(centerLat * pi / 180); // At Eau Claire
  }

  static List<TrackPoint> generateBikeTrackPoints(List<TrackPoint> originalPoints) {
    final mappedPoints = <TrackPoint>[];
    double totalDistance = 0.0;
    
    for (int i = 0; i < originalPoints.length; i++) {
      final point = originalPoints[i];
      
      // Calculate distance traveled in this second
      final distanceMeters = point.speed; // Speed in m/s = distance in meters for 1 second
      totalDistance += distanceMeters;
      
      // Calculate position along bike shape based on total distance
      final progress = totalDistance / (targetDistanceKm * 1000); // Convert target distance to meters
      final bikePoint = _getBikePointAtProgress(progress);
      
      // Create new track point with bike shape coordinates
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

  static ({double lat, double lon}) _getBikePointAtProgress(double progress) {
    // Normalize progress to repeat the bike shape
    final normalizedProgress = progress - progress.floor();
    
    // Calculate bike frame points
    final frontWheelCenter = (
      lat: centerLat - frameHeight/3,
      lon: centerLon - frameLength/2
    );
    final rearWheelCenter = (
      lat: centerLat - frameHeight/3,
      lon: centerLon + frameLength/4
    );
    
    // Define bike segments and their relative lengths
    final segments = [
      (start: frontWheelCenter, end: (lat: centerLat, lon: centerLon)), // Down tube
      (start: (lat: centerLat, lon: centerLon), end: (lat: centerLat + frameHeight/2, lon: centerLon)), // Seat tube
      (start: (lat: centerLat + frameHeight/2, lon: centerLon), end: frontWheelCenter), // Top tube
      (start: frontWheelCenter, end: rearWheelCenter), // Bottom line
    ];
    
    // Calculate total length of bike frame
    double totalLength = 0;
    for (final segment in segments) {
      totalLength += _calculateDistance(segment.start.lat, segment.start.lon,
                                     segment.end.lat, segment.end.lon);
    }
    
    // Find point along the bike frame
    double targetDistance = normalizedProgress * totalLength;
    double currentDistance = 0;
    
    for (final segment in segments) {
      final segmentLength = _calculateDistance(segment.start.lat, segment.start.lon,
                                           segment.end.lat, segment.end.lon);
      if (currentDistance + segmentLength >= targetDistance) {
        final segmentProgress = (targetDistance - currentDistance) / segmentLength;
        return (
          lat: segment.start.lat + (segment.end.lat - segment.start.lat) * segmentProgress,
          lon: segment.start.lon + (segment.end.lon - segment.start.lon) * segmentProgress,
        );
      }
      currentDistance += segmentLength;
    }
    
    // Default to center if something goes wrong
    return (lat: centerLat, lon: centerLon);
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Convert coordinate differences to meters
    final dlat = (lat2 - lat1) * metersPerDegreeLatitude;
    final dlon = (lon2 - lon1) * _getMetersPerDegreeLongitude();
    return sqrt(dlat * dlat + dlon * dlon);
  }

  static String generateGpxContent(
    String workoutName,
    List<TrackPoint> trackPoints,
  ) {
    if (trackPoints.isEmpty) {
      return ''; // Return empty string if no track points
    }

    // Generate bike shape track points based on speed and distance
    final bikeTrackPoints = generateBikeTrackPoints(trackPoints);

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
      final gpxContent = generateGpxContent(
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
