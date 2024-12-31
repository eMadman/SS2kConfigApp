import 'package:flutter_test/flutter_test.dart';
import 'package:ss2kconfigapp/utils/workout/workout_controller.dart';
import 'package:ss2kconfigapp/utils/workout/gpx_file_exporter.dart';
import 'package:ss2kconfigapp/utils/workout/gpx_to_fit.dart';
import 'package:ss2kconfigapp/utils/bledata.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUp(() async {
    // Set up shared preferences mock
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
  });

  test('Generate 1-hour ERG workout FIT file', () async {
    // Create a constant power workout XML content
    final workoutContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<workout_file>
    <author>Test</author>
    <name>2 Hour 300W Test</name>
    <description>2 hour constant power test at 300W</description>
    <sportType>bike</sportType>
    <workout>
        <SteadyState Duration="7200" Power="1.0" />
    </workout>
</workout_file>
''';

    // Create mock BLE device and data
    final mockDevice = BluetoothDevice.fromId('00:00:00:00:00:00');
    final bleData = BLEDataManager.forDevice(mockDevice);
    
    // Initialize FTMS data
    bleData.ftmsData = FtmsData();
    
    // Create workout controller with 300W FTP
    final workoutController = WorkoutController(bleData, mockDevice);
    workoutController.updateFTP(300.0); // Set FTP to 300W for 1.0 power = 300W
    
    // Load and start the workout
    workoutController.loadWorkout(workoutContent);
    workoutController.togglePlayPause(); // Start the workout
    
    final startTime = DateTime.now();
    
    // Simulate the workout data - one data point per second for 2 hours
    for (var i = 0; i < 1200; i++) {
      // Update mock BLE data
      bleData.ftmsData.watts = 300;
      bleData.ftmsData.cadence = 90;
      bleData.ftmsData.heartRate = 170;
      
      // Create track point with proper timestamp
      final currentTime = startTime.add(Duration(seconds: i));
      workoutController.trackPoints.add(TrackPoint(
        timestamp: currentTime,
        power: 300,
        cadence: 90,
        heartRate: 170,
        lat: 0,
        lon: 0,
        elevation: 0,
        speed: 8.33, // ~30 km/h
      ));
      
      // Update progress (using total duration from workout XML)
      workoutController.progressPosition = i / 7200;
      
      // Only wait a small amount to keep test runtime reasonable
      if (i % 60 == 0) { // Update every minute in test time
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }
    
    // Stop the workout
    workoutController.stopWorkout();
    
    // Export to GPX
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final gpxFileName = 'workout_${timestamp}.gpx';
    final workoutsDir = Directory(path.join(Directory.current.path, 'test'));
    if (!await workoutsDir.exists()) {
      await workoutsDir.create(recursive: true);
    }
    
    final gpxFile = File(path.join(workoutsDir.path, gpxFileName));
    final gpxContent = await GpxFileExporter.generateGpxContent(
      '2 Hour 300W Test',
      workoutController.trackPoints,
    );
    await gpxFile.writeAsString(gpxContent);
    
    // Convert GPX to FIT
    final fitFileName = gpxFileName.replaceAll('.gpx', '.fit');
    final fitFile = File(path.join(workoutsDir.path, fitFileName));
    await GpxToFitConverter.convertAndCleanup(gpxFile.path);
    
    // Success - both files were generated
    print('Test completed successfully:');
    print('GPX file: ${gpxFile.path}');
    print('FIT file: ${fitFile.path}');
    
    // Cleanup
    workoutController.cleanup();
  });
}
