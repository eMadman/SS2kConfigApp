import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bleConstants.dart';

class FTMSControlPoint {
  /// Writes target power to the FTMS Control Point characteristic
  /// [characteristic] - The FTMS Control Point characteristic to write to
  /// [targetPower] - The target power in watts
  static Future<void> writeTargetPower(
    BluetoothCharacteristic characteristic,
    int targetPower,
  ) async {
    try {
      // Create a buffer for the command (1 byte opcode + 2 bytes power)
      final ByteData buffer = ByteData(FTMS_TARGET_POWER_LENGTH);
      
      // Write opcode as first byte
      buffer.setUint8(0, FTMS_SET_TARGET_POWER_OPCODE);
      
      // Write power value as SINT16 in little-endian format
      buffer.setInt16(1, targetPower, Endian.little);
      
      // Convert ByteData to Uint8List for writing
      final Uint8List command = buffer.buffer.asUint8List();
      
      // Write to the characteristic
      await characteristic.write(command);
    } catch (e) {
      print('Error writing target power to FTMS: $e');
      rethrow;
    }
  }
}
