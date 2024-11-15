import 'dart:typed_data';
import 'fit_constants.dart';

/// Represents a field definition in a FIT file
class FieldDefinition {
  final int number;
  final int size;
  final int type;

  FieldDefinition(this.number, this.size, this.type);

  List<int> encode() {
    return [number, size, type];
  }
}

/// Base class for FIT messages
abstract class FitMessage {
  List<int> encode();
}

/// Represents a Definition Message in the FIT protocol
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

/// Represents a Data Message in the FIT protocol
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
      case FitConstants.TYPE_UINT8:
      case FitConstants.TYPE_UINT8Z:
        data.setUint8(0, value as int);
        break;
      case FitConstants.TYPE_UINT16:
      case FitConstants.TYPE_UINT16Z:
        data.setUint16(0, value as int, Endian.little);
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
      default:
        throw Exception('Unsupported field type: $type');
    }

    return data.buffer.asUint8List();
  }
}
