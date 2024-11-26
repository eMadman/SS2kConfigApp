// FTMS Control Point Op Codes
class FTMSOpCodes {
  // Control and General Settings
  static const int REQUEST_CONTROL = 0x00;
  static const int RESET = 0x01;

  // Workout Parameters
  static const int SET_TARGET_SPEED = 0x02;
  static const int SET_TARGET_INCLINATION = 0x03;
  static const int SET_TARGET_RESISTANCE_LEVEL = 0x04;
  static const int SET_TARGET_POWER = 0x05;
  static const int SET_TARGET_HEART_RATE = 0x06;
  static const int SET_TARGET_CADENCE = 0x14;
  static const int SET_INDOOR_BIKE_SIMULATION = 0x11;
  static const int SPIN_DOWN_CONTROL = 0x13;

  // Session Control
  static const int START_OR_RESUME = 0x07;
  static const int STOP_OR_PAUSE = 0x08;

  // Response Code
  static const int RESPONSE_CODE = 0x80;
}

// FTMS Response Result Codes
class FTMSResultCodes {
  static const int SUCCESS = 0x01;
  static const int OP_CODE_NOT_SUPPORTED = 0x02;
  static const int INVALID_PARAMETER = 0x03;
  static const int OPERATION_FAILED = 0x04;
  static const int CONTROL_NOT_PERMITTED = 0x05;
}

// FTMS Stop/Pause Parameters
class FTMSStopPauseParams {
  static const int STOP = 0x01;
  static const int PAUSE = 0x02;
}

// FTMS Spin Down Control Parameters
class FTMSSpinDownParams {
  static const int START = 0x01;
  static const int IGNORE = 0x02;
}

// FTMS Characteristic UUIDs
const String FTMS_CONTROL_POINT_CHARACTERISTIC_UUID = '00002AD9-0000-1000-8000-00805F9B34FB';

// FTMS Data Lengths and Resolutions
class FTMSDataConfig {
  // Data Lengths
  static const int TARGET_POWER_LENGTH = 3;  // 1 byte opcode + 2 bytes power value
  static const int TARGET_SPEED_LENGTH = 3;  // 1 byte opcode + 2 bytes speed value
  static const int TARGET_INCLINATION_LENGTH = 3;  // 1 byte opcode + 2 bytes inclination value
  static const int TARGET_RESISTANCE_LENGTH = 2;  // 1 byte opcode + 1 byte resistance value
  static const int TARGET_HEART_RATE_LENGTH = 2;  // 1 byte opcode + 1 byte heart rate value
  static const int TARGET_CADENCE_LENGTH = 3;  // 1 byte opcode + 2 bytes cadence value
  static const int STOP_PAUSE_LENGTH = 2;  // 1 byte opcode + 1 byte stop/pause parameter
  static const int INDOOR_BIKE_SIMULATION_LENGTH = 7;  // 1 byte opcode + 2 bytes wind speed + 2 bytes grade + 1 byte Crr + 1 byte Cw
  static const int SPIN_DOWN_CONTROL_LENGTH = 2;  // 1 byte opcode + 1 byte control parameter

  // Data Resolutions
  static const double SPEED_RESOLUTION = 0.01;  // km/h
  static const double INCLINATION_RESOLUTION = 0.1;  // percentage
  static const double RESISTANCE_RESOLUTION = 0.1;  // unitless
  static const double POWER_RESOLUTION = 1.0;  // watts
  static const double HEART_RATE_RESOLUTION = 1.0;  // BPM
  static const double CADENCE_RESOLUTION = 0.5;  // 1/minute
  
  // Indoor Bike Simulation Resolutions
  static const double WIND_SPEED_RESOLUTION = 0.001;  // meters per second
  static const double GRADE_RESOLUTION = 0.01;  // percentage
  static const double CRR_RESOLUTION = 0.0001;  // unitless
  static const double CW_RESOLUTION = 0.01;  // kg/m
}
