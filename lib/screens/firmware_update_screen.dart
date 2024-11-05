/*
 * Copyright (C) 2020  Anthony Doud
 * All rights reserved
 *
 * SPDX-License-Identifier: GPL-2.0-only
 */

import 'dart:async';
import 'dart:io' as io;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_archive/flutter_archive.dart';

import '../utils/bleOTA.dart';
import '../utils/wifi_ota.dart';
import '../utils/bledata.dart';
import '../widgets/device_header.dart';

class FirmwareUpdateScreen extends StatefulWidget {
  final BluetoothDevice device;

  const FirmwareUpdateScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<FirmwareUpdateScreen> createState() => _FirmwareUpdateState();
}

class _FirmwareUpdateState extends State<FirmwareUpdateScreen> {
  late BLEData bleData;
  final BleRepository bleRepo = BleRepository();
  String _githubFirmwareVersion = '';
  String _builtinFirmwareVersion = '';
  String _betaFirmwareVersion = '';
  Color _githubVersionColor = Color.fromARGB(255, 242, 0, 255);
  Color _builtinVersionColor = Color.fromARGB(255, 242, 0, 255);
  Color _betaVersionColor = Color.fromARGB(255, 242, 0, 255);
  Timer _loadingTimer = Timer.periodic(Duration(seconds: 30), (_loadingTimer) {});
  String? _betaFirmwareUrl;

  OtaPackage? otaPackage;

  StreamSubscription<int>? progressSubscription;
  StreamSubscription<BluetoothConnectionState>? charSubscription;
  StreamSubscription<BluetoothConnectionState>? disconnectSubscription;
  Timer? _disconnectTimer;
  double _progress = 0;
  bool _loaded = false;
  DateTime? startTime;
  String timeRemaining = 'Calculating...';
  bool _usingWifi = false;
  bool _waitingForDisconnect = false;

  bool firmwareCharReceived = false;
  bool _uploadCompleteDialogShown = false;
  bool updatingFirmware = false;

  final int BINARY = 1;
  final int PICKER = 2;
  final int URL = 3;
  final int BETA = 4;

  final String URLString = "https://github.com/doudar/OTAUpdates/raw/main/firmware.bin";
  
  @override
  void initState() {
    super.initState();
    bleData = BLEDataManager.forDevice(this.widget.device);
    if (this.bleData.charReceived.value == true) {
      _initialize();
    } else {
      this.bleData.charReceived.addListener(_charListener);
    }
    _loadingTimer = Timer.periodic(Duration(microseconds: 100), (_fwCheck) {
      if (this.bleData.firmwareVersion == "") {
        return;
      } else {
        _loaded = true;
        setState(() {
          _builtinVersionColor =
              _isNewerVersion(_builtinFirmwareVersion, this.bleData.firmwareVersion) ? Colors.green : Colors.red;
          _githubVersionColor =
              _isNewerVersion(_githubFirmwareVersion, this.bleData.firmwareVersion) ? Colors.green : Colors.red;
          _betaVersionColor =
              _isNewerVersion(_betaFirmwareVersion, this.bleData.firmwareVersion) ? Colors.green : Colors.red;
        });
        _fwCheck.cancel();
      }
    });
  }

  @override
  void dispose() {
    _disconnectTimer?.cancel();
    progressSubscription?.cancel();
    charSubscription?.cancel();
    disconnectSubscription?.cancel();
    _loadingTimer.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  void _showUploadCompleteDialog(bool isSuccess) {
    if (!_uploadCompleteDialogShown) {
      _uploadCompleteDialogShown = true;
      String title = isSuccess ? "Upload Successful" : "Upload Failed";
      String content = isSuccess
          ? "The firmware upload was successful."
          : "The device disconnected before the upload could complete.";

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: <Widget>[
              TextButton(
                child: Text("OK"),
                onPressed: () {
                  _uploadCompleteDialogShown = false;
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  Future<bool> _showConfirmDialog() async {
    return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Confirm Firmware Update'),
              content: Text('Are you sure you want to update the firmware?'),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  child: Text('Confirm'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _initialize() async {
    if (!bleData.isSimulated) {
      otaPackage = Esp32OtaPackage(this.bleData.firmwareDataCharacteristic, this.bleData.firmwareControlCharacteristic);
      await _progressStreamSubscription();
    }
    await _fetchGithubFirmwareVersion();
    await _fetchBuiltinFirmwareVersion();
    await _fetchBetaFirmwareVersion();
  }

  Future<void> _charListener() async {
    if (this.bleData.charReceived.value) {
      _initialize();
      if (mounted) {
        setState(() {});
      }
      this.bleData.charReceived.removeListener(_charListener);
    }
  }

  Future<void> _progressStreamSubscription() async {
    if (this.bleData.charReceived.value) {
      progressSubscription = otaPackage!.percentageStream.listen((event) {
        _progress = event / 100.0;
        if (event == 100) {
          _showUploadCompleteDialog(true);
        }
        setState(() {
          updateProgress();
        });
      });
    }
  }

  Future<void> _fetchBuiltinFirmwareVersion() async {
    final builtinVersion = await rootBundle.loadString('assets/version.txt');
    setState(() {
      _builtinFirmwareVersion = builtinVersion.trim();
      _builtinVersionColor =
          _isNewerVersion(_builtinFirmwareVersion, this.bleData.firmwareVersion) ? Colors.green : Colors.red;
      _builtinVersionColor =
          (this.bleData.firmwareVersion == "") ? Color.fromARGB(255, 242, 0, 255) : _builtinVersionColor;
    });
  }

  Future<void> _fetchGithubFirmwareVersion() async {
    final response = await http.get(Uri.parse('https://raw.githubusercontent.com/doudar/OTAUpdates/main/version.txt'));
    if (response.statusCode == 200) {
      final githubVersion = response.body.trim();
      setState(() {
        _githubFirmwareVersion = githubVersion;
        _githubVersionColor = _isNewerVersion(githubVersion, this.bleData.firmwareVersion) ? Colors.green : Colors.red;
        _githubVersionColor =
            (this.bleData.firmwareVersion == "") ? Color.fromARGB(255, 242, 0, 255) : _githubVersionColor;
      });
    }
  }

  Future<void> _fetchBetaFirmwareVersion() async {
    try {
      final response = await http.get(Uri.parse('https://api.github.com/repos/doudar/SmartSpin2k/releases/latest'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tagName = data['tag_name'] as String;
        final assets = data['assets'] as List;
        
        for (var asset in assets) {
          if (asset['name'].toString().endsWith('.bin.zip')) {
            _betaFirmwareUrl = asset['browser_download_url'] as String;
            break;
          }
        }

        setState(() {
          _betaFirmwareVersion = tagName;
          _betaVersionColor = _isNewerVersion(tagName, this.bleData.firmwareVersion) ? Colors.green : Colors.red;
          _betaVersionColor =
              (this.bleData.firmwareVersion == "") ? Color.fromARGB(255, 242, 0, 255) : _betaVersionColor;
        });
      }
    } catch (e) {
      print('Error fetching beta firmware version: $e');
    }
  }

  Future<String> _downloadAndExtractBetaFirmware() async {
    if (_betaFirmwareUrl == null) {
      throw Exception('Beta firmware URL not found');
    }

    final tempDir = await getTemporaryDirectory();
    final zipFile = io.File('${tempDir.path}/firmware.zip');
    final extractDir = io.Directory('${tempDir.path}/firmware');

    try {
      final response = await http.get(Uri.parse(_betaFirmwareUrl!));
      await zipFile.writeAsBytes(response.bodyBytes);

      if (await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }
      await extractDir.create();

      await ZipFile.extractToDirectory(
        zipFile: zipFile,
        destinationDir: extractDir,
      );

      final firmwareBin = io.File('${extractDir.path}/firmware.bin');
      if (await firmwareBin.exists()) {
        return firmwareBin.path;
      } else {
        throw Exception('firmware.bin not found in extracted files');
      }
    } finally {
      if (await zipFile.exists()) {
        await zipFile.delete();
      }
    }
  }

  bool _isNewerVersion(String versionA, String versionB) {
    final regex = RegExp(r'\d+');
    final versionAParts = regex.allMatches(versionA).map((m) => int.parse(m.group(0)!)).toList();
    final versionBParts = regex.allMatches(versionB).map((m) => int.parse(m.group(0)!)).toList();

    for (int i = 0; i < 3; i++) {
      if (i < versionAParts.length && i < versionBParts.length) {
        if (versionAParts[i] > versionBParts[i]) {
          return true;
        } else if (versionAParts[i] < versionBParts[i]) {
          return false;
        }
      } else if (i >= versionAParts.length && i < versionBParts.length) {
        return false;
      } else if (i < versionAParts.length && i >= versionBParts.length) {
        return true;
      }
    }
    return false;
  }

  void updateProgress() {
    if (startTime == null) {
      startTime = DateTime.now();
    }
    if (_progress > 0) {
      final timeElapsed = DateTime.now().difference(startTime!).inSeconds;
      final estimatedTotalTime = timeElapsed / _progress;
      final estimatedTimeRemaining = estimatedTotalTime - timeElapsed;
      timeRemaining = formatDuration(Duration(seconds: estimatedTimeRemaining.toInt()));
    }
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Future<void> startFirmwareUpdate(type) async {
    if(this.bleData.isSimulated) return;
    
    setState(() {
      updatingFirmware = true;
      _waitingForDisconnect = true;
      _progress = 0;
      startTime = null;
      timeRemaining = 'Checking WiFi availability...';
    });

    try {
      String binFilePath;
      String? url;

      if (type == BETA) {
        binFilePath = await _downloadAndExtractBetaFirmware();
      } else if (type == URL) {
        final tempDir = await getTemporaryDirectory();
        binFilePath = '${tempDir.path}/firmware.bin';
        final response = await http.get(Uri.parse(URLString));
        await io.File(binFilePath).writeAsBytes(response.bodyBytes);
      } else {
        binFilePath = 'assets/firmware.bin';
      }

      // Start monitoring for disconnect
      bool deviceDisconnected = false;
      disconnectSubscription = widget.device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.disconnected && _waitingForDisconnect) {
          deviceDisconnected = true;
          _disconnectTimer?.cancel();
          disconnectSubscription?.cancel();
          
          if (mounted) {
            setState(() {
              _waitingForDisconnect = false;
              _usingWifi = true;
              timeRemaining = 'Uploading via WiFi...';
            });
          }

          // Proceed with WiFi update
          final bool wifiSuccess = await WifiOTA.updateFirmware(
            deviceName: widget.device.advName,
            firmwarePath: binFilePath,
            onProgress: (progress) {
              if (mounted) {
                setState(() {
                  _progress = progress;
                  updateProgress();
                });
              }
            },
          );

          if (mounted) {
            if (wifiSuccess) {
              _showUploadCompleteDialog(true);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('WiFi update failed. Please try again or use the web interface directly.'),
                  duration: Duration(seconds: 5),
                ),
              );
            }
            setState(() {
              updatingFirmware = false;
            });
          }
        }
      });

      // Set timer to fall back to BLE if no disconnect occurs
      _disconnectTimer = Timer(Duration(seconds: 3), () {
        if (!deviceDisconnected && mounted) {
          disconnectSubscription?.cancel();
          setState(() {
            _waitingForDisconnect = false;
            _usingWifi = false;
          });
          _proceedWithBleUpdate(type, binFilePath, url);
        }
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          updatingFirmware = false;
        });
        _showUploadCompleteDialog(false);
      }
    }
  }

  Future<void> _proceedWithBleUpdate(int type, String binFilePath, String? url) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device still connected - proceeding with Bluetooth update (this may take up to 5 minutes)...'),
          duration: Duration(seconds: 5),
        ),
      );
    }

    try {
      this.bleData.isUpdatingFirmware = true;
      await otaPackage!.updateFirmware(
        this.widget.device,
        type,
        this.bleData.firmwareService,
        this.bleData.firmwareDataCharacteristic,
        this.bleData.firmwareControlCharacteristic,
        binFilePath: binFilePath,
        url: url,
      );
      this.bleData.isUpdatingFirmware = false;

      if (mounted) {
        setState(() {
          updatingFirmware = false;
        });
        _showUploadCompleteDialog(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          updatingFirmware = false;
        });
        _showUploadCompleteDialog(false);
      }
    }
  }

  List<Widget> _buildUpdateButtons() {
    return <Widget>[
      updatingFirmware
          ? Text(
              _waitingForDisconnect 
                ? "Checking WiFi update capability..."
                : "Don't leave this screen until the update completes",
              textAlign: TextAlign.center,
            )
          : Text(
              "The update will proceed via WiFi if available, otherwise Bluetooth will be used.",
              textAlign: TextAlign.center,
            ),
      SizedBox(height: 20),
      updatingFirmware ? Text('   ${(_progress * 100).round()}%') : SizedBox(),
      SizedBox(height: 20),
      updatingFirmware
          ? Column(children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 10),
              LinearProgressIndicator(
                value: _progress,
                minHeight: 10,
              ),
              Text('Time remaining: $timeRemaining'),
              Text(_usingWifi ? 'Updating via WiFi...' : 'Updating via Bluetooth...'),
            ])
          : Column(
              children: <Widget>[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeData().colorScheme.secondary,
                      foregroundColor: ThemeData().colorScheme.onSecondary),
                  onPressed: () async {
                    bool confirm = await _showConfirmDialog();
                    if (confirm) {
                      WakelockPlus.enable();
                      startFirmwareUpdate(BINARY);
                    }
                  },
                  child: Text(
                    textAlign: TextAlign.center,
                    'Use App Bundled Firmware\n${_builtinFirmwareVersion}',
                    style: TextStyle(color: _builtinVersionColor),
                  ),
                ),
                SizedBox(height: 10),
                io.Platform.isMacOS
                    ? SizedBox()
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeData().colorScheme.secondary,
                            foregroundColor: ThemeData().colorScheme.onSecondary),
                        onPressed: () async {
                          bool confirm = await _showConfirmDialog();
                          if (confirm) {
                            WakelockPlus.enable();
                            startFirmwareUpdate(PICKER);
                          }
                        },
                        child: Text(textAlign: TextAlign.center, 'Choose Firmware From Dialog'),
                      ),
                SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeData().colorScheme.secondary,
                      foregroundColor: ThemeData().colorScheme.onSecondary),
                  onPressed: () async {
                    bool confirm = await _showConfirmDialog();
                    if (confirm) {
                      WakelockPlus.enable();
                      startFirmwareUpdate(URL);
                    }
                  },
                  child: Text(
                    textAlign: TextAlign.center,
                    'Latest Stable Firmware from Github\n${_githubFirmwareVersion}',
                    style: TextStyle(color: _githubVersionColor),
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeData().colorScheme.secondary,
                      foregroundColor: ThemeData().colorScheme.onSecondary),
                  onPressed: _betaFirmwareUrl == null ? null : () async {
                    bool confirm = await _showConfirmDialog();
                    if (confirm) {
                      WakelockPlus.enable();
                      startFirmwareUpdate(BETA);
                    }
                  },
                  child: Text(
                    textAlign: TextAlign.center,
                    'Beta Firmware from Github\n${_betaFirmwareVersion}',
                    style: TextStyle(color: _betaVersionColor),
                  ),
                ),
              ],
            )
    ];
  }

  List<Widget> _notBLECompatible() {
    return <Widget>[
      _loaded
          ? Text("This firmware isn't compatible with the configuration app. Please upgrade your firmware via HTTP")
          : Text("Loading....Please Wait"),
    ];
  }

  Widget _legend() {
    return Column(
      children: <Widget>[
        SizedBox(
          height: 30,
        ),
        _loaded ? SizedBox() : Text("Determining Firmware Versions. Please Wait..."),
        _loaded ? Text("Color Coding Legend:") : CircularProgressIndicator(),
        SizedBox(
          height: 10,
        ),
        _loaded
            ? Text(
                "Firmware is NEWER than current.",
                style: TextStyle(color: Colors.green),
              )
            : SizedBox(),
        Text(
          "Firmware version is UNKNOWN.",
          style: TextStyle(color: Color.fromARGB(255, 242, 0, 255)),
        ),
        _loaded
            ? Text(
                "Firmware is OLDER than current.",
                style: TextStyle(color: Colors.red),
              )
            : SizedBox(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Firmware Update'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            DeviceHeader(
              device: this.widget.device,
              connectOnly: true,
            ),
            SizedBox(height: 50),
            Column(
              children: this.bleData.configAppCompatibleFirmware ? _buildUpdateButtons() : _notBLECompatible(),
            ),
            _legend(),
          ],
        ),
      ),
    );
  }
}
