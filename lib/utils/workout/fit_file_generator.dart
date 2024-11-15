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
  int _totalDistance = 0;
  int _maxPower = 0;
  int _maxHeartRate = 0;
  int _avgHeartRate = 0;
  int _totalHeartRateReadings = 0;
  int _avgCadence = 0;
  int _totalCadenceReadings = 0;

  FitFileGenerator() : _startTime = DateTime.now().millisecondsSinceEpoch ~/ 1000 {
    _initializeRecordFields();
    _writeFileHeader();
    _writeFileIdMessage();
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
    
    header.setUint8(0, FitConstants.HEADER_SIZE);
    header.setUint8(1, FitConstants.PROTOCOL_VERSION);
    header.setUint16(2, FitConstants.PROFILE_VERSION, Endian.little);
    header.setUint32(4, 0, Endian.little);
    
    for (var i = 0; i < FitConstants.FILE_TYPE.length; i++) {
      header.setUint8(8 + i, FitConstants.FILE_TYPE[i]);
    }

    _buffer.addAll(header.buffer.asUint8List());
  }

  void _writeFileIdMessage() {
    final fileIdFields = [
      FieldDefinition(0, FitConstants.SIZE_UINT8, FitConstants.TYPE_UINT8),    // type
      FieldDefinition(1, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),  // manufacturer
      FieldDefinition(2, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // product
      FieldDefinition(4, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),  // time_created
    ];

    final fileIdDefinition = DefinitionMessage(
      localMessageType: 0,
      globalMessageNumber: FitConstants.FILE_ID,
      fields: fileIdFields,
    );

    final fileIdData = DataMessage(
      localMessageType: 0,
      fields: {
        0: 4,                    // type (4 = activity)
        1: 255,                  // manufacturer (255 = development)
        2: 1,                    // product
        4: _startTime,           // time_created
      },
      fieldDefinitions: fileIdFields,
    );

    final List<int> definitionBytes = fileIdDefinition.encode();
    final List<int> dataBytes = fileIdData.encode();
    
    _buffer.addAll(definitionBytes);
    _buffer.addAll(dataBytes);
    _dataSize += definitionBytes.length + dataBytes.length;
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
    
    // Update statistics
    _totalDistance = distance;
    _maxPower = power > _maxPower ? power : _maxPower;
    _maxHeartRate = heartRate > _maxHeartRate ? heartRate : _maxHeartRate;
    _totalHeartRateReadings += heartRate;
    _avgHeartRate = _totalHeartRateReadings ~/ (elapsedTime > 0 ? elapsedTime : 1);
    _totalCadenceReadings += cadence;
    _avgCadence = _totalCadenceReadings ~/ (elapsedTime > 0 ? elapsedTime : 1);

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

  void _writeSessionMessage() {
    final sessionFields = [
      FieldDefinition(253, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32), // timestamp
      FieldDefinition(2, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),   // start_time
      FieldDefinition(7, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),   // total_elapsed_time
      FieldDefinition(9, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),   // total_distance
      FieldDefinition(18, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // avg_cadence
      FieldDefinition(15, FitConstants.SIZE_UINT8, FitConstants.TYPE_UINT8),    // avg_heart_rate
      FieldDefinition(16, FitConstants.SIZE_UINT8, FitConstants.TYPE_UINT8),    // max_heart_rate
      FieldDefinition(20, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // max_power
      FieldDefinition(5, FitConstants.SIZE_ENUM, FitConstants.TYPE_ENUM),       // sport
    ];

    final sessionDefinition = DefinitionMessage(
      localMessageType: 1,
      globalMessageNumber: FitConstants.SESSION,
      fields: sessionFields,
    );

    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final elapsedTime = currentTime - _startTime;

    final sessionData = DataMessage(
      localMessageType: 1,
      fields: {
        253: currentTime,      // timestamp
        2: _startTime,         // start_time
        7: elapsedTime,        // total_elapsed_time
        9: _totalDistance,     // total_distance
        18: _avgCadence,       // avg_cadence
        15: _avgHeartRate,     // avg_heart_rate
        16: _maxHeartRate,     // max_heart_rate
        20: _maxPower,         // max_power
        5: 2,                  // sport (2 = cycling)
      },
      fieldDefinitions: sessionFields,
    );

    final List<int> definitionBytes = sessionDefinition.encode();
    final List<int> dataBytes = sessionData.encode();
    
    _buffer.addAll(definitionBytes);
    _buffer.addAll(dataBytes);
    _dataSize += definitionBytes.length + dataBytes.length;
  }

  void _writeActivityMessage() {
    final activityFields = [
      FieldDefinition(253, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32), // timestamp
      FieldDefinition(1, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),   // total_timer_time
      FieldDefinition(2, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),   // num_sessions
      FieldDefinition(3, FitConstants.SIZE_ENUM, FitConstants.TYPE_ENUM),       // type
      FieldDefinition(4, FitConstants.SIZE_ENUM, FitConstants.TYPE_ENUM),       // event
    ];

    final activityDefinition = DefinitionMessage(
      localMessageType: 2,
      globalMessageNumber: FitConstants.ACTIVITY,
      fields: activityFields,
    );

    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final elapsedTime = currentTime - _startTime;

    final activityData = DataMessage(
      localMessageType: 2,
      fields: {
        253: currentTime,    // timestamp
        1: elapsedTime,      // total_timer_time
        2: 1,                // num_sessions
        3: 0,                // type (0 = manual)
        4: 1,                // event (1 = stop)
      },
      fieldDefinitions: activityFields,
    );

    final List<int> definitionBytes = activityDefinition.encode();
    final List<int> dataBytes = activityData.encode();
    
    _buffer.addAll(definitionBytes);
    _buffer.addAll(dataBytes);
    _dataSize += definitionBytes.length + dataBytes.length;
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
    // Write session and activity messages
    _writeSessionMessage();
    _writeActivityMessage();

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
