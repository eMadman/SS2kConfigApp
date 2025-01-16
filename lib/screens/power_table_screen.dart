/*
 * Copyright (C) 2020  Anthony Doud
 * All rights reserved
 *
 * SPDX-License-Identifier: GPL-2.0-only
 */
import 'dart:async';
import 'dart:math';

import 'package:ss2kconfigapp/utils/constants.dart';
import 'package:ss2kconfigapp/utils/extra.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/power_table_painter.dart';
import '../utils/bledata.dart';
import '../widgets/metric_card.dart';
import '../widgets/ss2k_app_bar.dart';

class PowerTableScreen extends StatefulWidget {
  final BluetoothDevice device;
  const PowerTableScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<PowerTableScreen> createState() => _PowerTableScreenState();
}

class _PowerTableScreenState extends State<PowerTableScreen> with SingleTickerProviderStateMixin {
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  late BLEData bleData;
  String statusString = '';
  late AnimationController _pulseController;
  double maxResistance = 0;
  final GlobalKey _chartKey = GlobalKey();

  // Trail tracking
  final List<Map<String, double>> _positionHistory = [];
  static const int maxTrailLength = 10;
  DateTime _lastPositionUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    bleData = BLEDataManager.forDevice(this.widget.device);
    requestAllCadenceLines();

    // Initialize pulse animation
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    // refresh the screen completely every VV seconds.
    Timer.periodic(const Duration(seconds: 15), (refreshTimer) {
      if (!this.widget.device.isConnected) {
        try {
          this.widget.device.connectAndUpdateStream();
        } catch (e) {
          print("failed to reconnect.");
        }
      } else {
        if (mounted) {
          requestAllCadenceLines();
        } else {
          refreshTimer.cancel();
        }
      }
    });

    // Request target position every second
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && this.widget.device.isConnected) {
        bleData.requestSetting(this.widget.device, targetPositionVname);
      }
    });

    // If the data is simulated, wait for a second before calling setState
    if (bleData.isSimulated) {
      this.bleData.isReadingOrWriting.value = true;
      Timer(Duration(seconds: 2), () {
        this.bleData.isReadingOrWriting.value = false;
        if (mounted) {
          print("demo delay");
          setState(() {
            // This empty setState call triggers a rebuild of the widget
            // after the demo data has been "loaded"
          });
        }
      });
    }
    rwSubscription();
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    this.bleData.isReadingOrWriting.removeListener(_rwListner);
    _pulseController.dispose();
    super.dispose();
  }

  Color getCadenceColor(int cadence) {
    if (cadence < 60) return Colors.red;
    if (cadence < 80) return Colors.orange;
    if (cadence <= 100) return Colors.green;
    return Colors.red; // Too high cadence
  }

  Color getInterpolatedCadenceColor(int cadence) {
    if (cadence < 60) {
      return Colors.red;
    } else if (cadence < 80) {
      double t = (cadence - 60) / 20.0; // normalize to 0-1 range
      return Color.lerp(Colors.red, Colors.orange, t)!;
    } else if (cadence <= 100) {
      double t = (cadence - 80) / 20.0; // normalize to 0-1 range
      return Color.lerp(Colors.orange, Colors.green, t)!;
    } else {
      double t = min((cadence - 100) / 20.0, 1.0); // normalize to 0-1 range, cap at 1
      return Color.lerp(Colors.green, Colors.red, t)!;
    }
  }

  bool _refreshBlocker = false;

  final List<Color> colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.brown,
    Colors.pink,
    Colors.teal,
    Colors.cyan,
    Colors.lime,
    Colors.indigo,
  ];

  Future rwSubscription() async {
    _connectionStateSubscription = this.widget.device.connectionState.listen((state) async {
      if (state == BluetoothConnectionState.connected) {
        // Request power table data when connection is restored
        requestAllCadenceLines();
      }
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      bleData.isReadingOrWriting.addListener(_rwListner);
    });
  }

  void _rwListner() async {
    if (_refreshBlocker) {
      return;
    }
    _refreshBlocker = true;
    await Future.delayed(Duration(microseconds: 500));

    if (bleData.FTMSmode == 0 || bleData.FTMSmode == 17) {
      bleData.simulatedTargetWatts = "";
    }
    if (mounted) {
      setState(() {});
    }
    _refreshBlocker = false;
  }

  void requestAllCadenceLines() async {
    for (int i = 0; i < 10; i++) {
      await bleData.requestSetting(this.widget.device, powerTableDataVname, extraByte: i);
    }
  }

  // Generate watts values up to 1000w in 30w increments
  final List<int> watts = List.generate((1000 ~/ 30) + 1, (index) => index * 30);
  final List<int> cadences = [60, 65, 70, 75, 80, 85, 90, 95, 100, 105];

  // Calculate max resistance from plotted data (excluding points above 1000w)
  double calculateMaxResistance() {
    double maxRes = 0;
    for (var row in bleData.powerTableData) {
      for (int i = 0; i < row.length && i * 30 <= 1000; i++) {
        if (row[i] != null && row[i]! > maxRes) {
          maxRes = row[i]!.toDouble();
        }
      }
    }
    return maxRes;
  }

  void _updatePositionHistory(double x, double y) {
    final now = DateTime.now();
    if (now.difference(_lastPositionUpdate).inMilliseconds >= 100) {
      // Update every 100ms
      _positionHistory.add({'x': x, 'y': y});
      if (_positionHistory.length > maxTrailLength) {
        _positionHistory.removeAt(0);
      }
      _lastPositionUpdate = now;
    }
  }

  Widget _buildChart(BuildContext context, BoxConstraints constraints) {
    if (bleData.ftmsData.watts > 0 && bleData.ftmsData.watts <= 1000 && maxResistance > 0) {
      _updatePositionHistory(bleData.ftmsData.watts.toDouble(), bleData.ftmsData.resistance.toDouble());
    }

    return CustomPaint(
      size: Size(constraints.maxWidth, constraints.maxHeight),
      painter: PowerTablePainter(
        powerTableData: bleData.powerTableData.map((row) =>
          row.map((value) => value?.toDouble()).toList()
        ).toList(),
        cadences: cadences,
        colors: colors,
        maxResistance: maxResistance,
        currentWatts: bleData.ftmsData.watts.toDouble(),
        currentResistance: bleData.ftmsData.resistance.toDouble(),
        currentCadence: bleData.ftmsData.cadence,
        positionHistory: _positionHistory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Update maxResistance whenever we rebuild
    maxResistance = calculateMaxResistance();

    return Scaffold(
      appBar: SS2KAppBar(
        device: widget.device,
        title: 'Resistance Chart',
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (bleData.simulatedTargetWatts != "")
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: MetricBox(
                        value: bleData.simulatedTargetWatts.toString(),
                        label: 'Target Watts',
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: MetricBox(
                      value: bleData.ftmsData.watts.toString(),
                      label: 'Watts',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: MetricBox(
                      value: bleData.ftmsData.cadence.toString(),
                      label: 'RPM',
                    ),
                  ),
                  if (bleData.ftmsData.heartRate != 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: MetricBox(
                        value: bleData.ftmsData.heartRate.toString(),
                        label: 'BPM',
                      ),
                    )
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: _buildChart,
              ),
            ),
            SizedBox(height: 16),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 8,
      children: List.generate(cadences.length, (index) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              color: colors[index % colors.length],
            ),
            SizedBox(width: 4),
            Text(
              '${cadences[index]}rpm',
              style: TextStyle(fontSize: 10),
            ),
          ],
        );
      }),
    );
  }
}
