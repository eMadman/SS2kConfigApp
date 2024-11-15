// FIT Protocol Constants
class FitConstants {
  // File Header Constants
  static const int HEADER_SIZE = 12;
  static const int PROTOCOL_VERSION = 0x10;
  static const int PROFILE_VERSION = 0x0100;
  static const List<int> FILE_TYPE = [0x2E, 0x46, 0x49, 0x54]; // ".FIT"

  // Message Types
  static const int DEFINITION_MESSAGE = 0x40;
  static const int DATA_MESSAGE = 0x00;

  // Global Message Numbers
  static const int FILE_ID = 0;
  static const int ACTIVITY = 34;
  static const int SESSION = 18;
  static const int LAP = 19;
  static const int RECORD = 20;

  // Field Numbers for Record Message
  static const int FIELD_TIMESTAMP = 253;
  static const int FIELD_HEART_RATE = 3;
  static const int FIELD_CADENCE = 4;
  static const int FIELD_POWER = 7;
  static const int FIELD_DISTANCE = 5;
  static const int FIELD_ELAPSED_TIME = 2;

  // Data Types
  static const int TYPE_ENUM = 0;
  static const int TYPE_SINT8 = 1;
  static const int TYPE_UINT8 = 2;
  static const int TYPE_SINT16 = 3;
  static const int TYPE_UINT16 = 4;
  static const int TYPE_SINT32 = 5;
  static const int TYPE_UINT32 = 6;
  static const int TYPE_STRING = 7;
  static const int TYPE_FLOAT32 = 8;
  static const int TYPE_FLOAT64 = 9;
  static const int TYPE_UINT8Z = 10;
  static const int TYPE_UINT16Z = 11;
  static const int TYPE_UINT32Z = 12;
  static const int TYPE_BYTE = 13;

  // Field Sizes (in bytes)
  static const int SIZE_ENUM = 1;
  static const int SIZE_SINT8 = 1;
  static const int SIZE_UINT8 = 1;
  static const int SIZE_SINT16 = 2;
  static const int SIZE_UINT16 = 2;
  static const int SIZE_SINT32 = 4;
  static const int SIZE_UINT32 = 4;
  static const int SIZE_FLOAT32 = 4;
  static const int SIZE_FLOAT64 = 8;

  // Architecture Type
  static const int LITTLE_ENDIAN = 0;
  static const int BIG_ENDIAN = 1;

  // CRC Table
  static const List<int> CRC_TABLE = [
    0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
    0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400,
  ];
}
