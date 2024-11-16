import 'dart:typed_data';
import 'fit_constants.dart';

/// Represents a field definition in a FIT file.
/// Each field has a number, size (in bytes), and type.
class FieldDefinition {
  final int number;
  final int size;
  final int type;

  FieldDefinition(this.number, this.size, this.type);

  List<int> encode() {
    return [number, size, type];
  }
}

/// Base class for FIT messages.
/// All FIT messages must implement the encode method.
abstract class FitMessage {
  List<int> encode();
}

/// Represents a Definition Message in the FIT protocol.
/// Definition messages describe the structure of subsequent data messages.
class DefinitionMessage extends FitMessage {
  final int localMessageType;
  final int globalMessageNumber;
  final List<FieldDefinition> fields;
  final int architecture;

  DefinitionMessage({
    required this.localMessageType,
    required this.globalMessageNumber,
    required this.fields,
    this.architecture = FitConstants.LITTLE_ENDIAN,
  });

  @override
  List<int> encode() {
    final ByteData header = ByteData(6);
    
    // Record Header
    header.setUint8(0, FitConstants.DEFINITION_MESSAGE | localMessageType);
    header.setUint8(1, 0); // Reserved
    header.setUint8(2, architecture);
    header.setUint16(3, globalMessageNumber, Endian.little);
    header.setUint8(5, fields.length);

    List<int> result = [];
    result.addAll(header.buffer.asUint8List());
    
    // Add field definitions
    for (var field in fields) {
      result.addAll(field.encode());
    }

    return result;
  }
}

/// Represents a Data Message in the FIT protocol.
/// Data messages contain the actual workout data values.
class DataMessage extends FitMessage {
  final int localMessageType;
  final Map<int, dynamic> fields;
  final List<FieldDefinition> fieldDefinitions;

  DataMessage({
    required this.localMessageType,
    required this.fields,
    required this.fieldDefinitions,
  });

  @override
  List<int> encode() {
    List<int> result = [FitConstants.DATA_MESSAGE | localMessageType];
    
    for (var fieldDef in fieldDefinitions) {
      final value = fields[fieldDef.number];
      if (value == null) continue;

      final bytes = _encodeField(value, fieldDef.type, fieldDef.size);
      result.addAll(bytes);
    }

    return result;
  }

  List<int> _encodeField(dynamic value, int type, int size) {
    final ByteData data = ByteData(size);
    
    switch (type) {
      case FitConstants.TYPE_ENUM:
        data.setUint8(0, value as int);
        break;
        
      case FitConstants.TYPE_SINT8:
        data.setInt8(0, value as int);
        break;
        
      case FitConstants.TYPE_UINT8:
      case FitConstants.TYPE_UINT8Z:
        data.setUint8(0, value as int);
        break;
        
      case FitConstants.TYPE_SINT16:
        data.setInt16(0, value as int, Endian.little);
        break;
        
      case FitConstants.TYPE_UINT16:
      case FitConstants.TYPE_UINT16Z:
        data.setUint16(0, value as int, Endian.little);
        break;
        
      case FitConstants.TYPE_SINT32:
        data.setInt32(0, value as int, Endian.little);
        break;
        
      case FitConstants.TYPE_UINT32:
      case FitConstants.TYPE_UINT32Z:
        data.setUint32(0, value as int, Endian.little);
        break;
        
      case FitConstants.TYPE_FLOAT32:
        data.setFloat32(0, value as double, Endian.little);
        break;
        
      case FitConstants.TYPE_FLOAT64:
        data.setFloat64(0, value as double, Endian.little);
        break;
        
      case FitConstants.TYPE_STRING:
        final String str = value as String;
        for (var i = 0; i < size && i < str.length; i++) {
          data.setUint8(i, str.codeUnitAt(i));
        }
        break;
        
      case FitConstants.TYPE_BYTE:
        data.setUint8(0, value as int);
        break;
        
      default:
        throw Exception('Unsupported field type: $type');
    }

    return data.buffer.asUint8List();
  }
}

/// Represents a File ID Message in the FIT protocol.
class FileIdMessage {
  static const int LOCAL_MESSAGE_TYPE = 0;

  static List<FieldDefinition> getFields() {
    return [
      FieldDefinition(0, FitConstants.SIZE_UINT8, FitConstants.TYPE_UINT8),    // type
      FieldDefinition(1, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // manufacturer
      FieldDefinition(2, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // product
      FieldDefinition(3, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // serial_number
      FieldDefinition(4, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),  // time_created
      FieldDefinition(5, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // number
    ];
  }
}

/// Represents a Device Info Message in the FIT protocol.
class DeviceInfoMessage {
  static const int LOCAL_MESSAGE_TYPE = 1;

  static List<FieldDefinition> getFields() {
    return [
      FieldDefinition(0, FitConstants.SIZE_UINT8, FitConstants.TYPE_UINT8),     // device_index
      FieldDefinition(1, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),   // manufacturer
      FieldDefinition(2, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),   // product
      FieldDefinition(3, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),   // serial_number
      FieldDefinition(4, FitConstants.SIZE_STRING, FitConstants.TYPE_STRING),   // product_name
      FieldDefinition(5, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),   // software_version
      FieldDefinition(253, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32), // timestamp
    ];
  }
}

/// Represents an Event Message in the FIT protocol.
class EventMessage {
  static const int LOCAL_MESSAGE_TYPE = 2;

  static List<FieldDefinition> getFields() {
    return [
      FieldDefinition(253, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32), // timestamp
      FieldDefinition(0, FitConstants.SIZE_ENUM, FitConstants.TYPE_ENUM),       // event
      FieldDefinition(1, FitConstants.SIZE_ENUM, FitConstants.TYPE_ENUM),       // event_type
      FieldDefinition(3, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),   // data
      FieldDefinition(4, FitConstants.SIZE_ENUM, FitConstants.TYPE_ENUM),       // event_group
    ];
  }
}

/// Represents a Record Message in the FIT protocol.
class RecordMessage {
  static const int LOCAL_MESSAGE_TYPE = 3;

  static List<FieldDefinition> getFields() {
    return [
      FieldDefinition(253, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32), // timestamp
      FieldDefinition(3, FitConstants.SIZE_UINT8, FitConstants.TYPE_UINT8),     // heart_rate
      FieldDefinition(4, FitConstants.SIZE_UINT8, FitConstants.TYPE_UINT8),     // cadence
      FieldDefinition(7, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),   // power
      FieldDefinition(6, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),   // speed
      FieldDefinition(5, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),   // distance
    ];
  }
}

/// Represents a Lap Message in the FIT protocol.
class LapMessage {
  static const int LOCAL_MESSAGE_TYPE = 4;

  static List<FieldDefinition> getFields() {
    return [
      FieldDefinition(253, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32), // timestamp
      FieldDefinition(2, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),   // start_time
      FieldDefinition(3, FitConstants.SIZE_SINT32, FitConstants.TYPE_SINT32),   // start_position_lat
      FieldDefinition(4, FitConstants.SIZE_SINT32, FitConstants.TYPE_SINT32),   // start_position_long
      FieldDefinition(5, FitConstants.SIZE_SINT32, FitConstants.TYPE_SINT32),   // end_position_lat
      FieldDefinition(6, FitConstants.SIZE_SINT32, FitConstants.TYPE_SINT32),   // end_position_long
      FieldDefinition(7, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),   // total_elapsed_time
      FieldDefinition(8, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),   // total_timer_time
      FieldDefinition(9, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),   // total_distance
      FieldDefinition(10, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),  // total_cycles
      FieldDefinition(254, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16), // message_index
      FieldDefinition(11, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // total_calories
      FieldDefinition(12, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // total_fat_calories
      FieldDefinition(13, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // avg_speed
      FieldDefinition(14, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // max_speed
      FieldDefinition(19, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // avg_power
      FieldDefinition(20, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // max_power
      FieldDefinition(21, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // total_ascent
      FieldDefinition(22, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // total_descent
      FieldDefinition(15, FitConstants.SIZE_UINT8, FitConstants.TYPE_UINT8),    // avg_heart_rate
      FieldDefinition(16, FitConstants.SIZE_UINT8, FitConstants.TYPE_UINT8),    // max_heart_rate
      FieldDefinition(17, FitConstants.SIZE_UINT8, FitConstants.TYPE_UINT8),    // avg_cadence
      FieldDefinition(18, FitConstants.SIZE_UINT8, FitConstants.TYPE_UINT8),    // max_cadence
      FieldDefinition(23, FitConstants.SIZE_ENUM, FitConstants.TYPE_ENUM),      // intensity
      FieldDefinition(24, FitConstants.SIZE_ENUM, FitConstants.TYPE_ENUM),      // lap_trigger
      FieldDefinition(25, FitConstants.SIZE_ENUM, FitConstants.TYPE_ENUM),      // sport
      FieldDefinition(26, FitConstants.SIZE_UINT8, FitConstants.TYPE_UINT8),    // event_group
      FieldDefinition(0, FitConstants.SIZE_ENUM, FitConstants.TYPE_ENUM),       // event
      FieldDefinition(1, FitConstants.SIZE_ENUM, FitConstants.TYPE_ENUM),       // event_type
    ];
  }
}

/// Represents a Session Message in the FIT protocol.
class SessionMessage {
  static const int LOCAL_MESSAGE_TYPE = 5;

  static List<FieldDefinition> getFields() {
    return [
      FieldDefinition(253, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32), // timestamp
      FieldDefinition(2, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),   // start_time
      FieldDefinition(3, FitConstants.SIZE_SINT32, FitConstants.TYPE_SINT32),   // start_position_lat
      FieldDefinition(4, FitConstants.SIZE_SINT32, FitConstants.TYPE_SINT32),   // start_position_long
      FieldDefinition(7, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),   // total_elapsed_time
      FieldDefinition(8, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),   // total_timer_time
      FieldDefinition(9, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),   // total_distance
      FieldDefinition(10, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),  // total_cycles
      FieldDefinition(29, FitConstants.SIZE_SINT32, FitConstants.TYPE_SINT32),  // nec_lat
      FieldDefinition(30, FitConstants.SIZE_SINT32, FitConstants.TYPE_SINT32),  // nec_long
      FieldDefinition(31, FitConstants.SIZE_SINT32, FitConstants.TYPE_SINT32),  // swc_lat
      FieldDefinition(32, FitConstants.SIZE_SINT32, FitConstants.TYPE_SINT32),  // swc_long
      FieldDefinition(254, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16), // message_index
      FieldDefinition(11, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // total_calories
      FieldDefinition(13, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // total_fat_calories
      FieldDefinition(14, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // avg_speed
      FieldDefinition(15, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // max_speed
      FieldDefinition(20, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // avg_power
      FieldDefinition(21, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // max_power
      FieldDefinition(22, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // total_ascent
      FieldDefinition(23, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // total_descent
      FieldDefinition(25, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // first_lap_index
      FieldDefinition(26, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),  // num_laps
      FieldDefinition(16, FitConstants.SIZE_UINT8, FitConstants.TYPE_UINT8),    // avg_heart_rate
      FieldDefinition(17, FitConstants.SIZE_UINT8, FitConstants.TYPE_UINT8),    // max_heart_rate
      FieldDefinition(18, FitConstants.SIZE_UINT8, FitConstants.TYPE_UINT8),    // avg_cadence
      FieldDefinition(19, FitConstants.SIZE_UINT8, FitConstants.TYPE_UINT8),    // max_cadence
      FieldDefinition(24, FitConstants.SIZE_UINT8, FitConstants.TYPE_UINT8),    // total_training_effect
      FieldDefinition(27, FitConstants.SIZE_UINT8, FitConstants.TYPE_UINT8),    // event_group
      FieldDefinition(28, FitConstants.SIZE_ENUM, FitConstants.TYPE_ENUM),      // trigger
      FieldDefinition(0, FitConstants.SIZE_ENUM, FitConstants.TYPE_ENUM),       // event
      FieldDefinition(1, FitConstants.SIZE_ENUM, FitConstants.TYPE_ENUM),       // event_type
      FieldDefinition(5, FitConstants.SIZE_ENUM, FitConstants.TYPE_ENUM),       // sport
      FieldDefinition(6, FitConstants.SIZE_ENUM, FitConstants.TYPE_ENUM),       // sub_sport
    ];
  }
}

/// Represents an Activity Message in the FIT protocol.
class ActivityMessage {
  static const int LOCAL_MESSAGE_TYPE = 6;

  static List<FieldDefinition> getFields() {
    return [
      FieldDefinition(253, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32), // timestamp
      FieldDefinition(0, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),   // total_timer_time
      FieldDefinition(5, FitConstants.SIZE_UINT32, FitConstants.TYPE_UINT32),   // local_timestamp
      FieldDefinition(1, FitConstants.SIZE_UINT16, FitConstants.TYPE_UINT16),   // num_sessions
      FieldDefinition(2, FitConstants.SIZE_ENUM, FitConstants.TYPE_ENUM),       // type
      FieldDefinition(3, FitConstants.SIZE_ENUM, FitConstants.TYPE_ENUM),       // event
      FieldDefinition(4, FitConstants.SIZE_ENUM, FitConstants.TYPE_ENUM),       // event_type
      FieldDefinition(6, FitConstants.SIZE_UINT8, FitConstants.TYPE_UINT8),     // event_group
    ];
  }
}
