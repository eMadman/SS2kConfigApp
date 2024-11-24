import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../lib/utils/workout/gpx_file_exporter.dart';
import '../lib/utils/workout/workout_controller.dart';
import '../lib/utils/bledata.dart';

// Mock BluetoothDevice for testing
class MockBluetoothDevice extends BluetoothDevice {
  MockBluetoothDevice() : super(
    remoteId: DeviceIdentifier('00:00:00:00:00:00'),
  );

  @override
  bool get isConnected => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  test('Simulate workout using test_ride.gpx data', () async {
    // Read the test_ride.gpx file to get workout data
    final testFile = File('assets/test_ride.gpx');
    final testContent = await testFile.readAsString();
    final testDoc = XmlDocument.parse(testContent);

    // Extract workout data points
    final workoutData = <({DateTime time, int power, int hr, int cadence})>[];
    final trkpts = testDoc.findAllElements('trkpt');

    for (final trkpt in trkpts) {
      final time = DateTime.parse(trkpt.findElements('time').first.innerText);
      final extensions = trkpt.findElements('extensions').first;
      final power = int.parse(extensions.findElements('power').first.innerText);
      final trackPointExt = extensions.findAllElements('gpxtpx:TrackPointExtension').first;
      final hr = int.parse(trackPointExt.findElements('gpxtpx:hr').first.innerText);
      final cad = int.parse(trackPointExt.findElements('gpxtpx:cad').first.innerText);

      workoutData.add((time: time, power: power, hr: hr, cadence: cad));
    }

    // Create a WorkoutController with mock BLEData and mock BluetoothDevice
    final bleData = BLEData();
    final mockDevice = MockBluetoothDevice();
    final workoutController = WorkoutController(bleData, mockDevice);

    // Simulate the workout by feeding data points
    for (final data in workoutData) {
      // Update BLE data to simulate sensor readings
      bleData.ftmsData.watts = data.power;
      bleData.ftmsData.heartRate = data.hr;
      bleData.ftmsData.cadence = data.cadence;

      // Let the controller process this data point
      // This will internally generate track points with proper bike shape coordinates
      workoutController.startProgress();
      await Future.delayed(const Duration(milliseconds: 100)); // Simulate time passing
    }

    // Generate GPX file from the workout data
    final generatedContent = await GpxFileExporter.generateGpxContent(
      'Test Workout',
      workoutController.trackPoints,
    );

    // Write the generated content to a test output file
    final outputFile = File('test/test_output.gpx');
    await outputFile.writeAsString(generatedContent);

    // Parse the generated content
    final generatedDoc = XmlDocument.parse(generatedContent);
    final generatedTrkpts = generatedDoc.findAllElements('trkpt');

    // Verify bike shape is being generated
    bool hasVaryingCoordinates = false;
    double? previousLat;
    double? previousLon;

    for (final trkpt in generatedTrkpts) {
      final lat = double.parse(trkpt.getAttribute('lat')!);
      final lon = double.parse(trkpt.getAttribute('lon')!);

      if (previousLat != null && previousLon != null) {
        if (lat != previousLat || lon != previousLon) {
          hasVaryingCoordinates = true;
          break;
        }
      }
      previousLat = lat;
      previousLon = lon;
    }

    expect(hasVaryingCoordinates, isTrue,
      reason: 'Generated track points should have varying coordinates from workout simulation');

    // Compare the workout data
    for (var i = 0; i < workoutData.length && i < generatedTrkpts.length; i++) {
      final originalData = workoutData[i];
      final generatedTrkpt = generatedTrkpts.elementAt(i);
      final generatedExtensions = generatedTrkpt.findElements('extensions').first;
      
      // Compare power
      final generatedPower = int.parse(generatedExtensions.findElements('power').first.innerText);
      expect(generatedPower, equals(originalData.power),
        reason: 'Power value mismatch at index $i');

      // Compare heart rate and cadence
      final generatedTrackPointExt = generatedExtensions.findAllElements('gpxtpx:TrackPointExtension').first;
      final generatedHr = int.parse(generatedTrackPointExt.findElements('gpxtpx:hr').first.innerText);
      final generatedCad = int.parse(generatedTrackPointExt.findElements('gpxtpx:cad').first.innerText);
      
      expect(generatedHr, equals(originalData.hr),
        reason: 'Heart rate value mismatch at index $i');
      expect(generatedCad, equals(originalData.cadence),
        reason: 'Cadence value mismatch at index $i');
    }
  });
}
