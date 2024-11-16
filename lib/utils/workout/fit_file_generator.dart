import 'dart:typed_data';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'fit_constants.dart';
import 'fit_message.dart';

class FitFileGenerator {
  static const String _fitFileKey = 'latest_fit_file';
  final List<int> _buffer = [];
  List<FieldDefinition> _recordFields = []; // Removed final keyword
  int _dataSize = 0;
  late DefinitionMessage _recordDefinition;
  final int _startTime;
  int _totalDistance = 0;
  int _maxPower = 0;
  int _maxHeartRate = 0;
  int _avgHeartRate = 0;
  int _totalHeartRateReadings = 0;
  int _avgCadence = 0;
  int _maxCadence = 0;
  int _totalCadenceReadings = 0;
  int _avgPower = 0;
  int _totalPowerReadings = 0;
  int _maxSpeed = 0;
  int _totalCalories = 0;
  int _totalAscent = 0;
  int _numLaps = 0;
  bool _hasWrittenTimerStart = false;

  // Bolingbrook, IL coordinates
  static const int BOLINGBROOK_LAT = 41734890; // 41.734890 degrees * 1e7
  static const int BOLINGBROOK_LONG = -88091952; // -88.091952 degrees * 1e7

  FitFileGenerator() 
      : _startTime = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - FitConstants.FIT_EPOCH_OFFSET {
    _initializeRecordFields();
    _writeFileHeader();
    _writeFileIdMessage();
    _writeDeviceInfoMessage();
    _writeRecordDefinition();
  }

  void _initializeRecordFields() {
    _recordFields = RecordMessage.getFields();
    _recordDefinition = DefinitionMessage(
      localMessageType: RecordMessage.LOCAL_MESSAGE_TYPE,
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
    final fileIdFields = FileIdMessage.getFields();

    final fileIdDefinition = DefinitionMessage(
      localMessageType: FileIdMessage.LOCAL_MESSAGE_TYPE,
      globalMessageNumber: FitConstants.FILE_ID,
      fields: fileIdFields,
    );

    final fileIdData = DataMessage(
      localMessageType: FileIdMessage.LOCAL_MESSAGE_TYPE,
      fields: {
        0: 4,                    // type (4 = activity)
        1: 255,                  // manufacturer (255 = development)
        2: 1,                    // product
        3: 1234,                 // serial_number
        4: _startTime,           // time_created
        5: 0,                    // number
      },
      fieldDefinitions: fileIdFields,
    );

    final List<int> definitionBytes = fileIdDefinition.encode();
    final List<int> dataBytes = fileIdData.encode();
    
    _buffer.addAll(definitionBytes);
    _buffer.addAll(dataBytes);
    _dataSize += definitionBytes.length + dataBytes.length;
  }

  void _writeDeviceInfoMessage() {
    final deviceInfoFields = DeviceInfoMessage.getFields();

    final deviceInfoDefinition = DefinitionMessage(
      localMessageType: DeviceInfoMessage.LOCAL_MESSAGE_TYPE,
      globalMessageNumber: FitConstants.DEVICE_INFO,
      fields: deviceInfoFields,
    );

    final deviceInfoData = DataMessage(
      localMessageType: DeviceInfoMessage.LOCAL_MESSAGE_TYPE,
      fields: {
        0: 0,                    // device_index (0 = creator)
        1: 255,                  // manufacturer (255 = development)
        2: 1,                    // product
        3: 1234,                 // serial_number
        4: "SS2K Config App",    // product_name
        5: 100,                  // software_version (1.00)
        253: _startTime,         // timestamp
      },
      fieldDefinitions: deviceInfoFields,
    );

    final List<int> definitionBytes = deviceInfoDefinition.encode();
    final List<int> dataBytes = deviceInfoData.encode();
    
    _buffer.addAll(definitionBytes);
    _buffer.addAll(dataBytes);
    _dataSize += definitionBytes.length + dataBytes.length;
  }

  void _writeEventMessage(bool isStart) {
    final eventFields = EventMessage.getFields();

    final eventDefinition = DefinitionMessage(
      localMessageType: EventMessage.LOCAL_MESSAGE_TYPE,
      globalMessageNumber: FitConstants.EVENT,
      fields: eventFields,
    );

    final currentTime = _getCurrentFitTime();

    final eventData = DataMessage(
      localMessageType: EventMessage.LOCAL_MESSAGE_TYPE,
      fields: {
        253: currentTime,        // timestamp
        0: 0,                    // event (0 = timer)
        1: isStart ? 0 : 4,      // event_type (0 = start, 4 = stop_all)
        3: 0,                    // data
        4: 0,                    // event_group
      },
      fieldDefinitions: eventFields,
    );

    final List<int> definitionBytes = eventDefinition.encode();
    final List<int> dataBytes = eventData.encode();
    
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
    if (!_hasWrittenTimerStart) {
      _writeEventMessage(true); // Write timer start event
      _hasWrittenTimerStart = true;
    }

    // Calculate speed (m/s) from power using a simple approximation
    // P = k * v^3 where k is approximately 0.125 for cycling
    // Therefore v = (P/0.125)^(1/3)
    double speedKmh = power > 0 ? math.pow(power / 0.125, 1/3).toDouble() : 0;
    double speedMps = speedKmh / 3.6; // Convert km/h to m/s
    int speedScaled = (speedMps * 1000).round(); // Convert to FIT file format (m/s * 1000)

    // Update max speed
    if (speedScaled > _maxSpeed) {
      _maxSpeed = speedScaled;
    }

    // Calculate timestamp based on start time and elapsed seconds
    final timestamp = _startTime + elapsedTime;
    
    // Update statistics
    _totalDistance = distance;
    _maxPower = power > _maxPower ? power : _maxPower;
    _maxHeartRate = heartRate > _maxHeartRate ? heartRate : _maxHeartRate;
    _maxCadence = cadence > _maxCadence ? cadence : _maxCadence;
    
    if (heartRate > 0) {
      _totalHeartRateReadings += heartRate;
      _avgHeartRate = _totalHeartRateReadings ~/ (elapsedTime > 0 ? elapsedTime : 1);
    }
    
    if (cadence > 0) {
      _totalCadenceReadings += cadence;
      _avgCadence = _totalCadenceReadings ~/ (elapsedTime > 0 ? elapsedTime : 1);
    }
    
    if (power > 0) {
      _totalPowerReadings += power;
      _avgPower = _totalPowerReadings ~/ (elapsedTime > 0 ? elapsedTime : 1);
    }

    // Update calories (simple estimation)
    _totalCalories = (_totalPowerReadings * 0.86 / 3600).round();

    final dataMessage = DataMessage(
      localMessageType: RecordMessage.LOCAL_MESSAGE_TYPE,
      fields: {
        FitConstants.FIELD_TIMESTAMP: timestamp,
        FitConstants.FIELD_HEART_RATE: heartRate,
        FitConstants.FIELD_CADENCE: cadence,
        FitConstants.FIELD_POWER: power,
        FitConstants.FIELD_SPEED: speedScaled,
        FitConstants.FIELD_DISTANCE: distance * 100, // Convert to centimeters for FIT file
      },
      fieldDefinitions: _recordFields,
    );

    final List<int> messageBytes = dataMessage.encode();
    _buffer.addAll(messageBytes);
    _dataSize += messageBytes.length;
  }

  void _writeLapMessage(int currentTime) {
    final lapFields = LapMessage.getFields();

    final lapDefinition = DefinitionMessage(
      localMessageType: LapMessage.LOCAL_MESSAGE_TYPE,
      globalMessageNumber: FitConstants.LAP,
      fields: lapFields,
    );

    final elapsedTime = currentTime - _startTime;

    final lapData = DataMessage(
      localMessageType: LapMessage.LOCAL_MESSAGE_TYPE,
      fields: {
        253: currentTime,           // timestamp
        2: _startTime,              // start_time
        3: BOLINGBROOK_LAT,         // start_position_lat
        4: BOLINGBROOK_LONG,        // start_position_long
        5: BOLINGBROOK_LAT,         // end_position_lat
        6: BOLINGBROOK_LONG,        // end_position_long
        7: elapsedTime * 1000,      // total_elapsed_time (ms)
        8: elapsedTime * 1000,      // total_timer_time (ms)
        9: _totalDistance * 100,    // total_distance (cm)
        10: 0,                      // total_cycles
        254: _numLaps,              // message_index
        11: _totalCalories,         // total_calories
        12: 0,                      // total_fat_calories
        13: _avgPower > 0 ? (math.pow(_avgPower / 0.125, 1/3) * 277.778).round() : 0,  // avg_speed
        14: _maxSpeed,              // max_speed
        19: _avgPower,              // avg_power
        20: _maxPower,              // max_power
        21: _totalAscent,           // total_ascent
        22: 0,                      // total_descent
        15: _avgHeartRate,          // avg_heart_rate
        16: _maxHeartRate,          // max_heart_rate
        17: _avgCadence,            // avg_cadence
        18: _maxCadence,            // max_cadence
        23: 0,                      // intensity (0 = active)
        24: 0,                      // lap_trigger (0 = manual)
        25: 2,                      // sport (2 = cycling)
        26: 0,                      // event_group
        0: 9,                       // event (9 = lap)
        1: 1,                       // event_type (1 = stop)
      },
      fieldDefinitions: lapFields,
    );

    final List<int> definitionBytes = lapDefinition.encode();
    final List<int> dataBytes = lapData.encode();
    
    _buffer.addAll(definitionBytes);
    _buffer.addAll(dataBytes);
    _dataSize += definitionBytes.length + dataBytes.length;
    _numLaps++;
  }

  void _writeSessionMessage() {
    final sessionFields = SessionMessage.getFields();

    final sessionDefinition = DefinitionMessage(
      localMessageType: SessionMessage.LOCAL_MESSAGE_TYPE,
      globalMessageNumber: FitConstants.SESSION,
      fields: sessionFields,
    );

    final currentTime = _getCurrentFitTime();
    final elapsedTime = currentTime - _startTime;

    final sessionData = DataMessage(
      localMessageType: SessionMessage.LOCAL_MESSAGE_TYPE,
      fields: {
        253: currentTime,           // timestamp
        2: _startTime,              // start_time
        3: BOLINGBROOK_LAT,         // start_position_lat
        4: BOLINGBROOK_LONG,        // start_position_long
        7: elapsedTime * 1000,      // total_elapsed_time (ms)
        8: elapsedTime * 1000,      // total_timer_time (ms)
        9: _totalDistance * 100,    // total_distance (cm)
        10: 0,                      // total_cycles
        29: BOLINGBROOK_LAT,        // nec_lat
        30: BOLINGBROOK_LONG,       // nec_long
        31: BOLINGBROOK_LAT,        // swc_lat
        32: BOLINGBROOK_LONG,       // swc_long
        254: 0,                     // message_index
        11: _totalCalories,         // total_calories
        13: 0,                      // total_fat_calories
        14: _avgPower > 0 ? (math.pow(_avgPower / 0.125, 1/3) * 277.778).round() : 0,  // avg_speed
        15: _maxSpeed,              // max_speed
        20: _avgPower,              // avg_power
        21: _maxPower,              // max_power
        22: _totalAscent,           // total_ascent
        23: 0,                      // total_descent
        25: 0,                      // first_lap_index
        26: _numLaps,               // num_laps
        16: _avgHeartRate,          // avg_heart_rate
        17: _maxHeartRate,          // max_heart_rate
        18: _avgCadence,            // avg_cadence
        19: _maxCadence,            // max_cadence
        24: 0,                      // total_training_effect
        27: 0,                      // event_group
        28: 0,                      // trigger (0 = activity_end)
        0: 8,                       // event (8 = session)
        1: 1,                       // event_type (1 = stop)
        5: 2,                       // sport (2 = cycling)
        6: 58,                      // sub_sport (58 = virtual_activity)
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
    final activityFields = ActivityMessage.getFields();

    final activityDefinition = DefinitionMessage(
      localMessageType: ActivityMessage.LOCAL_MESSAGE_TYPE,
      globalMessageNumber: FitConstants.ACTIVITY,
      fields: activityFields,
    );

    final currentTime = _getCurrentFitTime();
    final elapsedTime = currentTime - _startTime;

    final activityData = DataMessage(
      localMessageType: ActivityMessage.LOCAL_MESSAGE_TYPE,
      fields: {
        253: currentTime,           // timestamp
        0: elapsedTime * 1000,      // total_timer_time (ms)
        5: currentTime - 3600,      // local_timestamp (1 hour offset)
        1: 1,                       // num_sessions
        2: 0,                       // type (0 = manual)
        3: 26,                      // event (26 = activity)
        4: 1,                       // event_type (1 = stop)
        6: 0,                       // event_group
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
    final currentTime = _getCurrentFitTime();
    
    // Write timer stop event
    _writeEventMessage(false);
    
    // Write lap message
    _writeLapMessage(currentTime);
    
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

  int _getCurrentFitTime() {
    return (DateTime.now().millisecondsSinceEpoch ~/ 1000) - FitConstants.FIT_EPOCH_OFFSET;
  }
}
