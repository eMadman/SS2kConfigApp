import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'fit_constants.dart';
import 'fit_message.dart';

class FitFileGenerator {
  static const String _fitFileKey = 'latest_fit_file';
  final List<int> _buffer = [];
  final List<FieldDefinition> _recordFields = [];
  int _dataSize = 0;
  late DefinitionMessage _recordDefinition;
  final int _startTime;

  FitFileGenerator() : _startTime = DateTime.now().millisecondsSinceEpoch ~/ 1000 {
    _initializeRecordFields();
    _writeFileHeader();
    _writeRecordDefinition();
  }

  void _initializeRecordFields() {
    _recordFields.addAll([
      FieldDefinition(
        FitConstants.FIELD_TIMESTAMP,
        FitConstants.SIZE_UINT32,
        FitConstants.TYPE_UINT32
      ),
      FieldDefinition(
        FitConstants.FIELD_HEART_RATE,
        FitConstants.SIZE_UINT8,
        FitConstants.TYPE_UINT8
      ),
      FieldDefinition(
        FitConstants.FIELD_CADENCE,
        FitConstants.SIZE_UINT8,
        FitConstants.TYPE_UINT8
      ),
      FieldDefinition(
        FitConstants.FIELD_POWER,
        FitConstants.SIZE_UINT16,
        FitConstants.TYPE_UINT16
      ),
      FieldDefinition(
        FitConstants.FIELD_DISTANCE,
        FitConstants.SIZE_UINT32,
        FitConstants.TYPE_UINT32
      ),
      FieldDefinition(
        FitConstants.FIELD_ELAPSED_TIME,
        FitConstants.SIZE_UINT32,
        FitConstants.TYPE_UINT32
      ),
    ]);

    _recordDefinition = DefinitionMessage(
      localMessageType: 0,
      globalMessageNumber: FitConstants.RECORD,
      fields: _recordFields,
    );
  }

  void _writeFileHeader() {
    final ByteData header = ByteData(FitConstants.HEADER_SIZE);
    
    // Write header size
    header.setUint8(0, FitConstants.HEADER_SIZE);
    
    // Write protocol version
    header.setUint8(1, FitConstants.PROTOCOL_VERSION);
    
    // Write profile version
    header.setUint16(2, FitConstants.PROFILE_VERSION, Endian.little);
    
    // Data size will be updated later
    header.setUint32(4, 0, Endian.little);
    
    // Write .FIT
    for (var i = 0; i < FitConstants.FILE_TYPE.length; i++) {
      header.setUint8(8 + i, FitConstants.FILE_TYPE[i]);
    }

    _buffer.addAll(header.buffer.asUint8List());
  }

  void _writeRecordDefinition() {
    final List<int> definitionBytes = _recordDefinition.encode();
    _buffer.addAll(definitionBytes);
    _dataSize += definitionBytes.length;
  }

  void addRecord({
    required int heartRate,
    required int cadence,
    required int power,
    required int distance,
    required int elapsedTime,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    final dataMessage = DataMessage(
      localMessageType: 0,
      fields: {
        FitConstants.FIELD_TIMESTAMP: timestamp,
        FitConstants.FIELD_HEART_RATE: heartRate,
        FitConstants.FIELD_CADENCE: cadence,
        FitConstants.FIELD_POWER: power,
        FitConstants.FIELD_DISTANCE: distance,
        FitConstants.FIELD_ELAPSED_TIME: elapsedTime,
      },
      fieldDefinitions: _recordFields,
    );

    final List<int> messageBytes = dataMessage.encode();
    _buffer.addAll(messageBytes);
    _dataSize += messageBytes.length;
  }

  int _calculateCRC() {
    int crc = 0;
    for (var byte in _buffer) {
      var index = (crc ^ byte) & 0xF;
      crc = ((crc >> 4) & 0x0FFF) ^ FitConstants.CRC_TABLE[index];
      
      index = (crc ^ (byte >> 4)) & 0xF;
      crc = ((crc >> 4) & 0x0FFF) ^ FitConstants.CRC_TABLE[index];
    }
    return crc;
  }

  Future<void> finalize() async {
    // Update data size in header
    final ByteData sizeData = ByteData(4);
    sizeData.setUint32(0, _dataSize, Endian.little);
    _buffer.setRange(4, 8, sizeData.buffer.asUint8List());

    // Add CRC
    final int crc = _calculateCRC();
    final ByteData crcData = ByteData(2);
    crcData.setUint16(0, crc, Endian.little);
    _buffer.addAll(crcData.buffer.asUint8List());

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fitFileKey, _bufferToString(_buffer));
  }

  String _bufferToString(List<int> buffer) {
    return buffer.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<List<int>?> getLatestFitFile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? hexString = prefs.getString(_fitFileKey);
    if (hexString == null) return null;

    return _stringToBuffer(hexString);
  }

  static List<int> _stringToBuffer(String hexString) {
    List<int> buffer = [];
    for (var i = 0; i < hexString.length; i += 2) {
      buffer.add(int.parse(hexString.substring(i, i + 2), radix: 16));
    }
    return buffer;
  }

  static Future<void> clearLatestFitFile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_fitFileKey);
  }
}
