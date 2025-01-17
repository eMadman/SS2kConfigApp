/*
 * Copyright (C) 2020  Anthony Doud
 * All rights reserved
 *
 * SPDX-License-Identifier: GPL-2.0-only
 */
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/constants.dart';
import 'main_device_screen.dart';
import '../utils/snackbar.dart';
import '../utils/extra.dart';
import '../widgets/scan_result_tile.dart';
import '../utils/demo.dart';
import 'app_settings_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  int _tapCount = 0; // Tap counter
  bool _showDemoButton = false; // Initially, the demo button is not shown

  @override
  void initState() {
    super.initState();

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResults = results;
      if (mounted) {
        setState(() {});
      }
    }, onError: (e) {
      Snackbar.show(ABC.b, prettyException("Scan Error:", e), success: false);
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      _isScanning = state;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    super.dispose();
  }

  Future onScanPressed() async {
    //don't allow scan in demo mode - it ruins the setup
    if (_showDemoButton) return;
    try {
      if (kIsWeb) {
        // Web platform uses different scanning approach
        await FlutterBluePlus.startScan(
          withServices: [Guid(csUUID)],
          timeout: const Duration(seconds: 15),
        );
      } else {
        // Native platforms (Android/iOS)
        int divisor = !kIsWeb && io.Platform.isAndroid ? 8 : 1;
        await FlutterBluePlus.startScan(
          withServices: [Guid(csUUID)],
          timeout: const Duration(seconds: 15),
          continuousUpdates: true,
          continuousDivisor: divisor,
        );
      }
    } catch (e) {
      String errorMessage = kIsWeb
          ? "Web Bluetooth Error: Make sure your browser supports Web Bluetooth and you're using HTTPS"
          : prettyException("Start Scan Error:", e);
      Snackbar.show(ABC.b, errorMessage, success: false);
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future onStopPressed() async {
    try {
      FlutterBluePlus.stopScan();
    } catch (e) {
      Snackbar.show(ABC.b, prettyException("Stop Scan Error:", e), success: false);
    }
  }

  void onConnectPressed(BluetoothDevice device) {
    if (FlutterBluePlus.isScanningNow) {
      FlutterBluePlus.stopScan();
    }
    device.connectAndUpdateStream().catchError((e) {
      Snackbar.show(ABC.c, prettyException("Connect Error:", e), success: false);
    });
    MaterialPageRoute route = MaterialPageRoute(
        builder: (context) => MainDeviceScreen(device: device), settings: RouteSettings(name: '/MainDeviceScreen'));
    Navigator.of(context).push(route);
  }

  Future onRefresh() {
    if (_isScanning == false) {
      FlutterBluePlus.startScan(withServices: [Guid(csUUID)], timeout: const Duration(seconds: 15));
    }
    if (mounted) {
      setState(() {});
    }
    return Future.delayed(Duration(milliseconds: 500));
  }

  Widget buildScanButton(BuildContext context) {
    if (FlutterBluePlus.isScanningNow) {
      return ElevatedButton(
        child: const Icon(Icons.stop),
        onPressed: onStopPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeData().colorScheme.error, foregroundColor: ThemeData().colorScheme.onError,
          //maximumSize: Size.fromWidth(100),
        ),
      );
    } else {
      return ElevatedButton(
        child: const Text("SCAN"),
        onPressed: onScanPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeData().colorScheme.secondary, foregroundColor: ThemeData().colorScheme.onSecondary,
          //maximumSize: Size.fromWidth(50),
        ),
      );
    }
  }

  List<Widget> _buildScanResultTiles(BuildContext context) {
    return _scanResults
        .map(
          (r) => ScanResultTile(
            result: r,
            onTap: () => onConnectPressed(r.device),
          ),
        )
        .toList();
  }

  void _incrementTapCount() {
    setState(() {
      _tapCount++;
      if (_tapCount >= 5) {
        _showDemoButton = true; // Show the button after 5 taps
        // _tapCount = 0; // Reset the counter
      }
    });
  }

  void onDemoModePressed(context) {
    // Use the DemoDevice to simulate finding a SmartSpin2k device
    final demoDevice = DemoDevice();
    ScanResult simulatedScanResult = demoDevice.simulateSmartSpin2kScan();

    // Update the UI to display the simulated scan result
    setState(() {
      _scanResults = [simulatedScanResult]; // Replace existing scan results with the simulated one
      // If you want to keep existing scan results and add the simulated one, use `_scanResults.add(simulatedScanResult);` instead
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: Snackbar.snackBarKeyB,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Find Your SmartSpin2k:'),
          titleTextStyle: TextStyle(
            fontSize: 30,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AppSettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                children: <Widget>[
                  ..._buildScanResultTiles(context),
                  if (_scanResults.isEmpty) // This line checks if there are no scan results
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () async {
                              Uri url = Uri(
                                  scheme: 'https',
                                  host: 'SmartSpin2k.com',
                                  path: '/',
                                  fragment: ''); //http://SmartSpin2k.com";
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              }
                            },
                              child: Text(
                                'SmartSpin2k is a device that adds automatic resistance and virtual shifting to spin bikes. Click to learn more!',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Having Trouble?',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'If you cannot find your SmartSpin2k, try the following steps:',
                            style: TextStyle(fontSize: 18),
                          ),
                          SizedBox(height: 10),
                          Text(
                            '1. Ensure your SmartSpin2k is powered on and within range.\n'
                            '2. Turn off and on the Bluetooth on your device, then try scanning again.\n'
                            '3. Restart your SmartSpin2k device.\n'
                            '4. Each SmartSpin2k has a max connection of 3 apps (including this one). Close some if needed.\n'
                            '5. If none of these steps work, please contact support for further assistance.',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(100, 8, 100, 15),
                    child: buildScanButton(context),
                  ),
                ],
              ),
            ),
            if (_scanResults.isEmpty)
              Positioned(
                left: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _incrementTapCount,
                  behavior: HitTestBehavior.translucent,
                  child: Container(
                    width: 100, // Adjust the size as needed
                    height: 100, // Adjust the size as needed
                    color: Colors.transparent,
                  ),
                ),
              ),
            Visibility(
              child: ElevatedButton(
                onPressed: _showDemoButton
                    ? () {
                        // Enter demo mode logic here
                        onDemoModePressed(context); // Assuming this is your method to set up demo data

                        setState(() {
                          _showDemoButton = false; // Hide the button again after entering demo mode
                        });
                      }
                    : null, // Button does nothing if _showDemoButton is false
                child: Text("Tap Here to Enter\n Demo Mode"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              ),
              visible: _showDemoButton,
            ),
          ],
        ),
      ),
    );
  }
}

