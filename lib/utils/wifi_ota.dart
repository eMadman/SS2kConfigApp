import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/services.dart' show rootBundle;

class WifiOTA {
  /// Attempts to update firmware via WiFi
  /// Returns true if successful, false if failed
  static Future<bool> updateFirmware({
    required String deviceName,
    required String firmwarePath,
    required Function(double) onProgress,
  }) async {
    try {
      // Clean up device name for mDNS
      final cleanDeviceName = deviceName.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      print('WiFi OTA: Starting update for device: $cleanDeviceName');
      print('WiFi OTA: Using firmware path: $firmwarePath');
      
      // Initialize baseUrl - can be modified if mDNS fails
      var baseUrl = 'http://$cleanDeviceName.local';
      print('WiFi OTA: Attempting to connect to: $baseUrl');

      // First verify device is reachable
      try {
        print('WiFi OTA: Checking device availability...');
        final response = await http.get(Uri.parse('$baseUrl/OTAIndex'))
            .timeout(const Duration(seconds: 10)); // Increased timeout for mDNS resolution
        if (response.statusCode != 200) {
          print('WiFi OTA: Device returned non-200 status code: ${response.statusCode}');
          return false;
        }
        print('WiFi OTA: Device is available');
      } catch (e) {
        print('WiFi OTA: Failed to connect to device: $e');
        // Try alternate URL without .local suffix as fallback
        try {
          print('WiFi OTA: Trying alternate URL: http://$cleanDeviceName');
          final altResponse = await http.get(Uri.parse('http://$cleanDeviceName/OTAIndex'))
              .timeout(const Duration(seconds: 5));
          if (altResponse.statusCode != 200) {
            print('WiFi OTA: Alternate URL failed with status code: ${altResponse.statusCode}');
            return false;
          }
          // If alternate URL works, update baseUrl
          print('WiFi OTA: Alternate URL successful, using it for update');
          baseUrl = 'http://$cleanDeviceName';
        } catch (e2) {
          print('WiFi OTA: Alternate URL also failed: $e2');
          return false;
        }
      }

      // Get firmware bytes - handle both asset and file paths
      List<int> firmwareBytes;
      try {
        if (firmwarePath.startsWith('assets/')) {
          print('WiFi OTA: Loading firmware from assets');
          final byteData = await rootBundle.load(firmwarePath);
          firmwareBytes = byteData.buffer.asUint8List();
        } else {
          print('WiFi OTA: Loading firmware from file system');
          final file = File(firmwarePath);
          firmwareBytes = await file.readAsBytes();
        }
        print('WiFi OTA: Firmware loaded, size: ${firmwareBytes.length} bytes');
        onProgress(0.1); // Initial progress update
      } catch (e) {
        print('WiFi OTA: Failed to load firmware: $e');
        return false;
      }

      // Prepare multipart request
      print('WiFi OTA: Preparing upload request');
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/update'));
      
      // Create a stream that reports progress
      final byteStream = Stream.fromIterable([firmwareBytes]);
      int bytesSent = 0;
      final totalBytes = firmwareBytes.length;

      // Transform the stream to track progress
      final progressStream = byteStream.transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
            bytesSent += data.length;
            // Scale progress from 10% to 90% during upload
            onProgress(0.1 + (0.8 * bytesSent / totalBytes));
            sink.add(data);
          },
        ),
      );

      // Add firmware file with correct name and content type
      final multipartFile = http.MultipartFile(
        'update', // Form field name must match the ESP32 web interface
        progressStream,
        totalBytes,
        filename: 'firmware.bin',
        contentType: MediaType('application', 'octet-stream'),
      );
      request.files.add(multipartFile);

      // Send request
      print('WiFi OTA: Sending firmware...');
      final streamedResponse = await request.send();
      
      if (streamedResponse.statusCode != 200) {
        print('WiFi OTA: Upload failed with status code: ${streamedResponse.statusCode}');
        return false;
      }

      print('WiFi OTA: Upload successful, processing response');
      final contentLength = streamedResponse.contentLength ?? 0;
      int bytesReceived = 0;

      await for (final chunk in streamedResponse.stream) {
        bytesReceived += chunk.length;
        if (contentLength > 0) {
          // Scale progress from 90% to 100% during response
          onProgress(0.9 + (0.1 * bytesReceived / contentLength));
        }
      }

      // Ensure we reach 100% at completion
      onProgress(1.0);
      print('WiFi OTA: Update completed successfully');
      return true;
    } catch (e) {
      print('WiFi OTA Error: $e');
      return false;
    }
  }
}
