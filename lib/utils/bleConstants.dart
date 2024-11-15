// FTMS Control Point Op Codes
const int FTMS_SET_TARGET_POWER_OPCODE = 0x05;

// FTMS Characteristic UUIDs
const String FTMS_CONTROL_POINT_CHARACTERISTIC_UUID = '00002AD9-0000-1000-8000-00805F9B34FB';

// FTMS Data Lengths
const int FTMS_TARGET_POWER_LENGTH = 3;  // 1 byte opcode + 2 bytes power value
