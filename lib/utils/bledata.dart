/*
 * Copyright (C) 2020  Anthony Doud
 * All rights reserved
 *
 * SPDX-License-Identifier: GPL-2.0-only
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'constants.dart';
import 'ftmsControlPoint.dart';
import 'bleConstants.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/snackbar.dart';

class BLEDataManager {
  static final Map<String, BLEData> _dataMap = {};

  static BLEData forDevice(BluetoothDevice device) {
    if (!_dataMap.containsKey(device.remoteId.str)) {
      _dataMap[device.remoteId.str] = BLEData();
    }
    return _dataMap[device.remoteId.str]!;
  }

  static void updateDataForDevice(BluetoothDevice device, BLEData data) {
    _dataMap[device.remoteId.str] = data;
  }

  static void clearDataForDevice(BluetoothDevice device) {
    _dataMap.remove(device.remoteId.str);
  }
}

class FtmsData {
  late int cadence;
  late int watts;
  late int _targetERG;
  late int resistance;
  late int mode;
  late int heartRate;
  late int speed;

  // Add getter and setter for targetERG to monitor changes
  int get targetERG => _targetERG;
  set targetERG(int value) {
    if (value != _targetERG) {
      _targetERG = value;
      // Notify any listeners that target power has changed
      if (onTargetPowerChanged != null) {
        onTargetPowerChanged!(value);
      }
      // If target power is 0, switch to simulation mode with 0 incline
      if (value == 0 && onModeChanged != null) {
        onModeChanged!(true); // true indicates switch to simulation mode
      }
    }
  }

  // Callback for target power changes
  void Function(int)? onTargetPowerChanged;
  // Callback for mode changes (simulation vs target power)
  void Function(bool)? onModeChanged;

  FtmsData({
    this.cadence = 0,
    this.watts = 0,
    int targetERG = 0,
    this.mode = 0, // 0 = no control, 1 = sim, 2 = ERG.
    this.resistance = 0,
    this.heartRate = 0,
    this.speed = 0,
  }) : _targetERG = targetERG;
}

class BLEData {
  ValueNotifier<int> rssi = ValueNotifier(0);
  ValueNotifier<bool> charReceived = ValueNotifier(false);
  ValueNotifier<bool> isReadingOrWriting = ValueNotifier(false);
  StreamSubscription<BluetoothConnectionState>? connectionStateSubscription;
  StreamSubscription<bool>? isConnectingSubscription;
  StreamSubscription<bool>? isDisconnectingSubscription;
  late BluetoothService firmwareService;
  late BluetoothCharacteristic firmwareDataCharacteristic;
  late BluetoothCharacteristic firmwareControlCharacteristic;
  BluetoothCharacteristic? _myCharacteristic;
  BluetoothCharacteristic? ftmsControlPointCharacteristic;
  BluetoothCharacteristic? indoorBikeCharacteristic;
  BluetoothConnectionState connectionState = BluetoothConnectionState.disconnected;
  List<BluetoothService> services = [];
  FtmsData ftmsData = FtmsData();
  bool isSimulated = false; //Is this a demo device?
  bool isConnecting = false;
  bool isDisconnecting = false;
  bool configAppCompatibleFirmware = false;
  bool isUpdatingFirmware = false;
  String firmwareVersion = "";
  String simulatedTargetWatts = "";
  String simulatedFTMSmode = "";
  int FTMSmode = 0;
  bool simulateTargetWatts = false;

  List<List<int?>> powerTableData = List.generate(
    10,
    (i) => List.generate(38, (j) => null),
  );

  var customCharacteristic = customCharacteristicFramework;

  String getVnameValue(String vName) {
    var characteristic = customCharacteristic.firstWhere(
      (c) => c["vName"] == vName && c["value"] != noFirmSupport,
      orElse: () => {"value": "0"},
    );
    return characteristic["value"].toString();
  }

  setupConnection(BluetoothDevice device) async {
  if (device.isConnected) {
    await _discoverServices(device);
    this.subscribed = false;
    if (services.length > 1) {
      await _findChar();
      await updateCustomCharacter(device);
      
      // Set up target power change listener
      ftmsData.onTargetPowerChanged = (int newPower) async {
        if (ftmsControlPointCharacteristic != null) {
          try {
            await FTMSControlPoint.writeTargetPower(
              ftmsControlPointCharacteristic!,
              newPower,
            );
          } catch (e) {
            print('Error writing target power to FTMS: $e');
          }
        }
      };

      // Set up mode change listener
      ftmsData.onModeChanged = (bool toSimulation) async {
        if (ftmsControlPointCharacteristic != null) {
          try {
            if (toSimulation) {
              // Switch to simulation mode with 0 incline
              await FTMSControlPoint.writeIndoorBikeSimulation(
                ftmsControlPointCharacteristic!,
                windSpeed: 0,
                grade: 0,
                crr: 0,
                cw: 0,
              );
            }
          } catch (e) {
            print('Error switching FTMS mode: $e');
          }
        }
      };
    }
  }
}

  BluetoothCharacteristic getMyCharacteristic(BluetoothDevice device) {
    late BluetoothCharacteristic _char;

    if (device.isConnected) {
      _discoverServices(device);
      if (services.length > 1) {
        _findChar();
      }
    }
    if (_myCharacteristic != null) {
      charReceived.value = true;
      _char = _myCharacteristic!;
    } else {
      charReceived.value = false;
    }
    return _char;
  }

  Future _discoverServices(BluetoothDevice device) async {
    if (this.isSimulated) return;
    if (!this.isReadingOrWriting.value) {
      this.isReadingOrWriting.value = true;
      try {
        if (services.length < 1) {
          services = await device.discoverServices();
        }
      } catch (e) {
        print(e);
      }
      this.isReadingOrWriting.value = false;
    }
  }

  Future _findChar() async {
    if (this.isSimulated) return;
    if (!this.isReadingOrWriting.value) {
      this.isReadingOrWriting.value = true;
      while (!charReceived.value) {
        try {
          // custom characteristic
          BluetoothService cs = services.first;
          for (BluetoothService s in services) {
            if (s.uuid == Guid(csUUID)) {
              cs = s;
              break;
            }
          }
          List<BluetoothCharacteristic> characteristics = cs.characteristics;
          for (BluetoothCharacteristic c in characteristics) {
            if (c.uuid == Guid(ccUUID)) {
              _myCharacteristic = c;
              _myCharacteristic!.setNotifyValue(true);
            }
          }
          // firmware
          for (BluetoothService s in services) {
            if (s.uuid == Guid("4FAFC201-1FB5-459E-8FCC-C5C9C331914B")) {
              firmwareService = s;
              configAppCompatibleFirmware = true;
              break;
            }
          }
          if (configAppCompatibleFirmware) {
            characteristics = firmwareService.characteristics;
            for (BluetoothCharacteristic c in characteristics) {
              print(c.uuid.toString());
              if (c.uuid == Guid("62ec0272-3ec5-11eb-b378-0242ac130005")) {
                firmwareDataCharacteristic = c;
              }
              if (c.uuid == Guid("62ec0272-3ec5-11eb-b378-0242ac130003")) {
                firmwareControlCharacteristic = c;
              }
            }
          }
          //ftms
          BluetoothService ftmsService = services.first;
          for (BluetoothService s in services) {
            if (s.uuid == Guid(ftmsServiceUUID)) {
              ftmsService = s;
              characteristics = ftmsService.characteristics;
              break;
            }
          }
          for (BluetoothCharacteristic c in characteristics) {
            if (c.uuid == Guid(ftmsIndoorBikeDataUUID)) {
              indoorBikeCharacteristic = c;
              indoorBikeCharacteristic!.setNotifyValue(true);
              print("subscribed to indoor bike characteristic");
            }
            if (c.uuid == Guid(FTMS_CONTROL_POINT_CHARACTERISTIC_UUID)) {
              ftmsControlPointCharacteristic = c;
              ftmsControlPointCharacteristic!.setNotifyValue(true);
              print("subscribed to ftms control point characteristic");
            }
          }
          charReceived.value = true;
        } catch (e) {
          charReceived.value = false;
        }
      }
    }
    isReadingOrWriting.value = false;
  }

  ///Data Helpers****************************************************************

  bool subscribed = false;
  final _lastRequestStopwatch = Stopwatch();
// only used as a flag to prevent multiple concurrent instances of updateCustomCharacter
  bool _inUpdateLoop = false;

  Future updateCustomCharacter(BluetoothDevice device) async {
    if (this.isSimulated) return;
    if (_inUpdateLoop) {
      return;
    }
    if (Platform.isAndroid) {
      try {
        device.requestMtu(515);
      } catch (e) {}
    }
    _inUpdateLoop = true;
    if (!subscribed) {
      decode(device);
      updateIndoorBikeData(device);
    }
    if(!_myCharacteristic!.isNotifying){
      _myCharacteristic!.setNotifyValue(true);
    }
    if (!_lastRequestStopwatch.isRunning) {
      await requestSettings(device);
      _lastRequestStopwatch.start();
    } else if (_lastRequestStopwatch.elapsed > Duration(seconds: 5)) {
      _lastRequestStopwatch.reset();
      await requestSettings(device);
    }
    this.isReadingOrWriting.value = false;
    _inUpdateLoop = false;
  }

  void updateIndoorBikeData(device) {
    try {
      if (!indoorBikeCharacteristic!.isNotifying) {
        indoorBikeCharacteristic!.setNotifyValue(true);
      }
      ;
    } catch (e) {
      print("no FTMS characteristic");
      return;
    }

    // TODO handle cancelling subscription

    final subscription = indoorBikeCharacteristic!.onValueReceived.listen((value) {
      if (value.length < 2) {
        throw ArgumentError('FTMS Characteristic data list is too short');
      }
      this.isReadingOrWriting.value = true;
      Uint8List data = Uint8List.fromList(value);
      ByteData byteData = ByteData.sublistView(data);

      int flags = byteData.getUint16(0, Endian.little);
      int index = 2;

      // Print flags in binary format for debugging
      String binaryFlags = flags.toRadixString(2).padLeft(16, '0');
      print('Flags (binary): $binaryFlags');

      // Reset fields
      ftmsData.cadence = 0;
      ftmsData.watts = 0;
      ftmsData.heartRate = 0;
      ftmsData.speed = 0;

      ftmsData.speed = byteData.getUint16(index, Endian.little) ~/ 100; // resolution 0.01
      index += 2;

      if ((flags & (1 << 1)) != 0) {
        //not used
        index += 2;
      }

      if ((flags & (1 << 2)) != 0) {
        ftmsData.cadence = byteData.getUint16(index, Endian.little) ~/ 2; // resolution 0.5
        index += 2;
      }

      if ((flags & (1 << 3)) != 0) {
        // not used
        index += 2;
      }
      if ((flags & (1 << 4)) != 0) {
        //not used
        index += 3;
      }

      if ((flags & (1 << 5)) != 0) {
        ftmsData.resistance = byteData.getInt16(index, Endian.little);
        index += 2;
      }

      if ((flags & (1 << 6)) != 0) {
        ftmsData.watts = byteData.getInt16(index, Endian.little);
        index += 2;
      }

      if ((flags & (1 << 7)) != 0) {
        //not used
        index += 2;
      }
      if ((flags & (1 << 8)) != 0) {
        //not used
        index += 1;
      }

      if ((flags & (1 << 9)) != 0) {
        ftmsData.heartRate = byteData.getUint8(index);
        index += 1;
      }
      this.isReadingOrWriting.value = false;
    });
    device.cancelWhenDisconnected(subscription);
  }

  void findNSave(BluetoothDevice device, Map c, String find) {
    if (this.isSimulated) return;
    // Firmware that wasn't Compatible with the app would reboot whenever this command was read.
    if (!this.configAppCompatibleFirmware && c["vName"] == saveVname) {
      return;
    }
    if (c["vName"] == find) {
      try {
        write(device, [0x02, int.parse(c["reference"]), 0x01]);
      } catch (e) {
        Snackbar.show(ABC.c, "Failed to write to SmartSpin2k $e", success: false);
      }
    }
  }

  Future saveAllSettings(BluetoothDevice device) async {
    if (this.isSimulated) return;
    this.isReadingOrWriting.value = true;
    await this.customCharacteristic.forEach((c) => c["isSetting"] ? writeToSS2k(device, c) : ());
    await this.customCharacteristic.forEach((c) => findNSave(device, c, saveVname));
    this.isReadingOrWriting.value = false;
  }

  Future reboot(BluetoothDevice device) async {
    if (this.isSimulated) return;
    await this.customCharacteristic.forEach((c) => findNSave(device, c, rebootVname));
  }

  Future resetToDefaults(BluetoothDevice device) async {
    if (this.isSimulated) return;
    this.isReadingOrWriting.value = true;
    await this.customCharacteristic.forEach((c) => findNSave(device, c, resetVname));
    this.isReadingOrWriting.value = false;
  }

  Future resetPowerTable(BluetoothDevice device) async {
    if (this.isSimulated) return;
    this.isReadingOrWriting.value = true;
    await this.customCharacteristic.forEach((c) => findNSave(device, c, resetPowerTableVname));
    this.isReadingOrWriting.value = false;
  }

//request all settings
  Future requestSettings(BluetoothDevice device) async {
    if (this.isSimulated) return;
    this.isReadingOrWriting.value = true;
    _write(Map c) {
      // Firmware that wasn't Compatible with the app would reboot whenever this command was read.
      if (!this.configAppCompatibleFirmware && c["vName"] == saveVname) {
        return;
      }
      try {
        write(device, [0x01, int.parse(c["reference"])]);
      } catch (e) {
        Snackbar.show(ABC.c, "Failed to write to SmartSpin2k $e", success: false);
      }
    }

    await this.customCharacteristic.forEach((c) => _write(c));
    this.isReadingOrWriting.value = false;
  }

//request single setting
  Future requestSetting(BluetoothDevice device, String name, {int? extraByte}) async {
    if (this.isSimulated) return;
    _request(Map c) {
      // Firmware that wasn't Compatible with the app would reboot whenever this command was read.
      if (!this.configAppCompatibleFirmware && c["vName"] == saveVname) {
        return;
      }
      if (c["vName"] == name) {
        try {
          List<int> value = [0x01, int.parse(c["reference"])];
          if (extraByte != null) {
            value.add(extraByte);
          }
          write(device, value);
        } catch (e) {
          Snackbar.show(ABC.c, "Failed to request setting $e", success: false);
        }
      } else {
        // skipped
      }
    }

    await this.customCharacteristic.forEach((c) => _request(c));
  }

  int getPrecision(Map c) {
    int precision = 0;
    switch (c["type"]) {
      case "string":
      case "int":
      case "long":
        precision = 0;
        break;
      default:
        precision = 2;
    }
    return precision;
  }

  void writeToSS2k(BluetoothDevice device, Map c, {String s = ""}) {
    if (this.isSimulated) return;
    //If a specific value wasn't passed, use the previously saved value
    if (s == "") {
      s = c["value"];
    }
    //If the value wasn't read by the firmware, don't try to set it.
    if (s == noFirmSupport) {
      return;
    }

    List<int> value = [0x02, int.parse(c["reference"])];

    switch (c["type"]) {
      case "string":
        value = value + s.codeUnits;
      case "int":
        int t = double.parse(s).round();
        final list = new Uint64List.fromList([t]);
        final bytes = new Uint8List.view(list.buffer);
        final out = bytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}');
        print('bytes: ${out}');
        value = [0x02, int.parse(c["reference"]), int.parse(out.elementAt(0)), int.parse(out.elementAt(1))];
        break;
      case "bool":
        (s == "false") ? s = "0" : s = "1";
        int t = double.parse(s).round();
        final list = new Uint64List.fromList([t]);
        final bytes = new Uint8List.view(list.buffer);
        final out = bytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}');
        print('bytes: ${out}');
        value = [0x02, int.parse(c["reference"]), int.parse(out.elementAt(0)), int.parse(out.elementAt(1))];
        break;
      case "float":
        int t = (double.parse(s) * 10).round();
        final list = new Uint64List.fromList([t]);
        final bytes = new Uint8List.view(list.buffer);
        final out = bytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}');
        print('bytes: ${out}');
        value = [0x02, int.parse(c["reference"]), int.parse(out.elementAt(0)), int.parse(out.elementAt(1))];
        break;
      case "long":
        int t = double.parse(s).round();
        final list = new Uint64List.fromList([t]);
        final bytes = new Uint8List.view(list.buffer);
        final out = bytes.map((b) => '0x${b.toRadixString(32).padLeft(2, '0')}');
        print('bytes: ${out}');
        value = [
          0x02,
          int.parse(c["reference"]),
          int.parse(out.elementAt(0)),
          int.parse(out.elementAt(1)),
          int.parse(out.elementAt(2)),
          int.parse(out.elementAt(3))
        ];
        break;
      case "powerTableData":
        // Define the INT_MIN value for uint16_t in little endian format
        const int intMinValue = -32768;

        // Loop through each row of the tableData
        for (int rowIndex = 0; rowIndex < this.powerTableData.length; rowIndex++) {
          List<int?> row = this.powerTableData[rowIndex];
          List<int> rowValue = [];

          // Convert each entry in the row to its little-endian byte representation
          for (int? entry in row) {
            int valueToConvert = entry ?? intMinValue;
            final list = Uint16List.fromList([valueToConvert]);
            final bytes = Uint8List.view(list.buffer);
            final out = bytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}');
            print('bytes: ${out}');
            rowValue.add(bytes[0]); // Low byte
            rowValue.add(bytes[1]); // High byte
          }

          // Combine the request, reference, and row data
          List<int> rowToSend = [0x02, int.parse(c["reference"]), rowIndex + 1] + rowValue;

          // Write the data to the device
          try {
            write(device, rowToSend);
          } catch (e) {
            Snackbar.show(ABC.c, "Failed to write to SmartSpin2k $e", success: false);
            return;
          }
        }
        break;

      default:
      //value = [0xff];
    }
    try {
      write(device, value);
    } catch (e) {
      Snackbar.show(ABC.c, "Failed to write to SmartSpin2k $e", success: false);
    }
  }

  void write(BluetoothDevice device, List<int> value) {
    if (this.isSimulated) return;
    this.isReadingOrWriting.value = true;
    if (this.getMyCharacteristic(device).device.isConnected) {
      try {
        this.getMyCharacteristic(device).write(value);
      } catch (e) {
        Snackbar.show(ABC.c, "Failed to write to SmartSpin2k $e", success: false);
      }
    } else {
      Snackbar.show(ABC.c, "Failed to write to SmartSpin2k - Net Connected", success: false);
    }
    this.isReadingOrWriting.value = false;
  }

  void decode(BluetoothDevice device) {
    if (this.isSimulated) return;
    final subscription = this.getMyCharacteristic(device).onValueReceived.listen((value) {
      this.isReadingOrWriting.value = true;
      subscribed = true;
      if (value[0] == 0x80) {
        var length = value.length;
        var t = new Uint8List(length);
        //
        for (var c in this.customCharacteristic) {
          if (int.parse(c["reference"]) == value[1]) {
            for (var i = 0; i < length; i++) {
              t[i] = value[i];
            }
            var data = t.buffer.asByteData();

            switch (c["type"]) {
              case "int":
                {
                  if (data.lengthInBytes < 4) {
                    c["value"] = noFirmSupport;
                  } else {
                    c["value"] = data.getInt16(2, Endian.little).toString();

                    simulatedTargetWatts = (c["reference"] == "0x28") ? c["value"] : simulatedTargetWatts;
                    if (c["vName"] == FTMSModeVname) {
                      this.simulatedFTMSmode = c["value"];
                      FTMSmode = int.parse(this.simulatedFTMSmode);
                    }
                  }

                  break;
                }

              case "bool":
                {
                  String b = (value[2] == 0) ? "false" : "true";
                  c["value"] = b;
                  if (c["vName"] == simulateTargetWattsVname) {
                    if (b == "true") {
                      this.simulateTargetWatts = true;
                      print('Simulate target watts = $simulateTargetWatts');
                    } else if (b == "false") {
                      this.simulateTargetWatts = false;
                      print('Simulate target watts = $simulateTargetWatts');
                    }
                  }
                  break;
                }
              case "float":
                {
                  c["value"] = (data.getInt16(2, Endian.little) / 10).toString();
                  break;
                }
              case "long":
                {
                  c["value"] = data.getInt32(2, Endian.little).toString();

                  break;
                }
              case "string":
                {
                  //remove the data bytes
                  var subT = new Uint8List(length - 2);
                  for (int i = 0; i < length - 2; i++) {
                    subT[i] = t[i + 2];
                  }
                  c["value"] = utf8.decode(subT);
                  // Format Found Devices into a JSON String
                  if (c["vName"] == foundDevicesVname) {
                    String _pm = "";
                    String _hrm = "";
                    for (var i in this.customCharacteristic) {
                      if (i["vName"] == connectedHRMVname) {
                        _hrm = i["value"];
                      }
                      if (i["vName"] == connectedPWRVname) {
                        _pm = i["value"];
                      }
                    }
                    String t = c["value"];
                    String tList = "";
                    if (t == " " || t == "null") {
                      t = "";
                    } else {
                      t = t.substring(1, t.length - 1);
                      t += ",";
                    }
                    tList = defaultDevices +
                        t +
                        '"device -5":{"name":"' +
                        _hrm +
                        '","UUID":"0x180d"},"device -6":{"name":"' +
                        _pm +
                        '","UUID":"0x1818"}}]';
                    c["value"] = tList;
                    print(c["value"]);
                  }
                  //Set the firmware version
                  if (c["vName"] == fwVname) {
                    this.firmwareVersion = c["value"];
                    print("FW Version Was Updated!! ${c['value']} ${this.firmwareVersion}");
                  }
                  break;
                }
              case "powerTableData":
                int cadenceRow = value[2];
                if (cadenceRow >= 0 && cadenceRow < this.powerTableData.length) {
                  List<int?> row = [];
                  for (int i = 3; i < value.length; i += 2) {
                    if (data.getInt16(i, Endian.little) == -32768) {
                      row.add(null);
                    } else {
                      row.add(data.getInt16(i, Endian.little));
                    }
                  }
                  this.powerTableData[cadenceRow] = row;
                }
                break;
              default:
                {
                  String type = c["type"];
                  print("No decoder found for $type");
                }
            }

            break;
          }
        }
      } else if (value[0] == 0xff) {
        for (var c in this.customCharacteristic) {
          if (int.parse(c["reference"]) == value[1]) {
            c["value"] = noFirmSupport;
          }
        }
      }
      this.isReadingOrWriting.value = false;
    }); //VV This is handled by the subscription flag.
    device.cancelWhenDisconnected(subscription);
  }
}
