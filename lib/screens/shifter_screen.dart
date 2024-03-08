/*
 * Copyright (C) 2020  Anthony Doud
 * All rights reserved
 *
 * SPDX-License-Identifier: GPL-2.0-only
 */
import 'dart:async';
import 'package:SS2kConfigApp/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../widgets/device_header.dart';
import '../utils/bledata.dart';

class ShifterScreen extends StatefulWidget {
  final BluetoothDevice device;
  const ShifterScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<ShifterScreen> createState() => _ShifterScreenState();
}

class _ShifterScreenState extends State<ShifterScreen> {
  late BLEData bleData;
  late Map c;
  String t = "Loading";
  StreamSubscription? _charSubscription;
  late StreamSubscription<BluetoothConnectionState> _connectionStateSubscription;

  @override
  void initState() {
    bleData = BLEDataManager.forDevice(this.widget.device);
    this.bleData.customCharacteristic.forEach((i) => i["vName"] == shiftVname ? c = i : ());
    this.bleData.isReadingOrWriting.addListener(_rwListner);
    startSubscription();
    super.initState();
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    if (this.bleData.charReceived.value) {
      _charSubscription?.cancel();
    }
    this.bleData.isReadingOrWriting.removeListener(_rwListner);
    WakelockPlus.disable();
    super.dispose();
  }

  void _rwListner() {
    if (mounted) {
      setState(() {
        t = c["value"] ?? "Loading";
      });
    }
  }

  Future startSubscription() async {
    t = c["value"] ?? "Loading";
    _connectionStateSubscription = this.widget.device.connectionState.listen((state) async {
      if (mounted) {
        if (state == BluetoothConnectionState.connected) {
          this.bleData.setupConnection(this.widget.device);
          t = c["value"] ?? "Loading";
        } else {
          t = "Loading";
        }
        setState(() {});
      }
    });
    if (this.bleData.charReceived.value) {
      try {
        _charSubscription = this.bleData.getMyCharacteristic(this.widget.device).onValueReceived.listen((data) async {
          if (c["vName"] == shiftVname) {
            setState(() {
              t = c["value"] ?? "Loading";
            });
          }
        });
      } catch (e) {
        print("Subscription Failed, $e");
      }
    }
  }

  shift(int amount) {
    if (t != "Loading") {
      String _t = (int.parse(c["value"]) + amount).toString();
      c["value"] = _t;
      this.bleData.writeToSS2K(this.widget.device, c);
    }
    WakelockPlus.enable();
  }

  Widget _buildShiftButton(IconData icon, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[300], // Button color
        foregroundColor: Colors.black, // Icon color
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))), // Oval shape
        padding: EdgeInsets.symmetric(vertical: 48, horizontal: 30), // Padding for oval shape
      ),
      child: Icon(icon, size: 60), // Icon size
      onPressed: onPressed,
    );
  }

  Widget _buildGearDisplay(String gearNumber) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 5,
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        gearNumber,
        style: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
        child: Scaffold(
      backgroundColor: Color(0xffebebeb),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "Virtual Shifter",
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.normal,
            fontSize: 20,
            color: Color(0xff000000),
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            DeviceHeader(device: this.widget.device, connectOnly: true),
            Spacer(flex: 1),
            _buildShiftButton(Icons.arrow_upward, () {
              shift(1);
            }),
            Spacer(flex: 1),
            _buildGearDisplay(t), // Assuming '0' is the current gear value
            Spacer(flex: 1),
            _buildShiftButton(Icons.arrow_downward, () {
              shift(-1);
            }),
            Spacer(flex: 1),
          ],
        ),
      ),
    ));
  }
}
