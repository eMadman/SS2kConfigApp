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
          print('Timer expired and WiFi return code not 200 $response.statusCode');
          return false;
        }
      } catch (e) {
        return false;
      }

      // Prepare multipart request
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/update'));
      
      // Add firmware file with correct name and content type
      final file = await http.MultipartFile.fromPath(
        'update', // Form field name must match the ESP32 web interface
        firmwarePath,
        contentType: MediaType('application', 'octet-stream'),
        filename: 'firmware.bin'
      );
      request.files.add(file);

      // Send request and track progress
      final streamedResponse = await request.send();
      
      if (streamedResponse.statusCode != 200) {
        print('WiFi return code not 200 $streamedResponse.statusCode');
        return false;
      }

      final contentLength = streamedResponse.contentLength ?? 0;
      int bytesReceived = 0;

      await for (final chunk in streamedResponse.stream) {
        bytesReceived += chunk.length;
        if (contentLength > 0) {
          onProgress(bytesReceived / contentLength);
        }
      }

      return true;
    } catch (e) {
      print('WiFi OTA Error: $e');
      return false;
    }
  }
}
