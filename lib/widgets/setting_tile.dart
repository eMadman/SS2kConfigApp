/*
 * Copyright (C) 2020  Anthony Doud
 * All rights reserved
 *
 * SPDX-License-Identifier: GPL-2.0-only
 */
import 'dart:async';

import 'package:ss2kconfigapp/utils/constants.dart';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import "../widgets/slider_card.dart";
import "../widgets/bool_card.dart";
import "../widgets/plain_text_card.dart";
import '../widgets/dropdown_card.dart';

import '../utils/bledata.dart';

class SettingTile extends StatefulWidget {
  final BluetoothDevice device;
  final Map c;
  const SettingTile({Key? key, required this.device, required this.c}) : super(key: key);

  @override
  State<SettingTile> createState() => _SettingTileState();
}

class _SettingTileState extends State<SettingTile> {
  late String text = this.c["value"].toString();
  StreamSubscription? _charSubscription;
  late BLEData bleData;
  Map get c => this.widget.c;
  late String _value;

  @override
  void initState() {
    super.initState();
    bleData = BLEDataManager.forDevice(this.widget.device);
    _value = valueFormatter();
    startSubscription();
  }

  @override
  void dispose() {
    _charSubscription?.cancel();
    super.dispose();
  }

  Future startSubscription() async {
    if (this.bleData.charReceived.value) {
      try {
        _charSubscription = this.bleData.getMyCharacteristic(this.widget.device).onValueReceived.listen((data) async {
          if (_value != c["value"]) {
            _value = valueFormatter();
            setState(() {
              _value;
            });
          }
        });
      } catch (e) {
        print("Subscription Failed, $e");
      }
    }
  }

  Widget widgetPicker() {
    Widget ret;
    switch (c["type"]) {
      case "int":
      case "float":
      case "long":
        ret = SingleChildScrollView(
          child: sliderCard(device: this.widget.device, c: c),
        );
      case "string":
        if ((c["vName"] == connectedHRMVname) || (c["vName"] == connectedPWRVname)) {
          ret = SingleChildScrollView(
            child: DropdownCard(device: this.widget.device, c: c),
          );
        } else {
          ret = SingleChildScrollView(
            child: plainTextCard(device: this.widget.device, c: c),
          );
        }
      case "bool":
        ret = SingleChildScrollView(
          child: boolCard(device: this.widget.device, c: c),
        );
      default:
        ret = SingleChildScrollView(
          child: plainTextCard(device: this.widget.device, c: c),
        );
    }

    return Card(
      color: Colors.black12,
      child: Column(
        children: <Widget>[
          Text(c["textDescription"], style: TextStyle(color: Colors.white)),
          SizedBox(height: 50),
          Center(
            child: Hero(
                tag: c["vName"],
                child: Material(
                  child: ret,
                  type: MaterialType.transparency,
                )),
          ),
          SizedBox(height: 50),
          Text("Settings are immediate for the current session.\nClick save to make them persistent.",
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
        ],
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
      ),
    );
  }

  String valueFormatter() {
    String _ret = c["value"] ?? "";
    if (_ret == "true" || _ret == "false") {
      _ret = (_ret == "true") ? "On" : "Off";
    }
    _ret = (c["vName"] == passwordVname) ? "**********" : _ret;
    return _ret;
  }

  @override
  Widget build(BuildContext context) {
    SizedBox(height: 10);
    return Hero(
      tag: c["vName"],
      child: Material(
        type: MaterialType.transparency,
        child: Card(
          margin: EdgeInsets.fromLTRB(10, 5, 10, 5),
          elevation: 4,
          child: ListTile(
            shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
             ),
            title: Column(
              children: <Widget>[
                Text((c["humanReadableName"]),
                    textAlign: TextAlign.left, style: Theme.of(context).textTheme.labelLarge),
                Text(
                  _value,
                  textAlign: TextAlign.right,
                ),
                Icon(Icons.edit_note_sharp),
              ],
            ),
            tileColor: (c["value"] == noFirmSupport) ? deactiveBackgroundColor : Colors.black12,
            onTap: () {
              if (c["value"] == noFirmSupport) {
              } else {
                Navigator.push(
                  context,
                  fadeRoute(
                    Scaffold(
                      appBar: AppBar(title: const Text('Edit Setting')),
                      body: Center(child: widgetPicker()),
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}

Route fadeRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
}
