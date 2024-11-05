import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class WifiOTA {
  /// Attempts to update firmware via WiFi
  /// Returns true if successful, false if failed
  static Future<bool> updateFirmware({
    required String deviceName,
    required String firmwarePath,
    required Function(double) onProgress,
  }) async {
    try {
      final baseUrl = 'http://$deviceName.local';
      
      // First verify device is reachable
      try {
        final response = await http.get(Uri.parse('$baseUrl/OTAIndex'))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode != 200) {
          return false;
        }
      } catch (e) {
        return false;
      }

      // Get the file size for progress calculation
      final file = File(firmwarePath);
      final totalBytes = await file.length();

      // Create a stream from the file that reports progress
      final fileStream = file.openRead();
      int bytesSent = 0;

      // Transform the stream to track progress while maintaining List<int> type
      final progressStream = fileStream.transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
            bytesSent += data.length;
            onProgress(bytesSent / totalBytes);
            sink.add(data);
          },
        ),
      );

      // Prepare multipart request
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/update'));
      
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
      final streamedResponse = await request.send();
      
      // Wait for the response
      final response = await http.Response.fromStream(streamedResponse);
      
      // Return true if successful (200 OK)
      return response.statusCode == 200;
      
    } catch (e) {
      print('WiFi OTA Error: $e');
      return false;
    }
  }
}
