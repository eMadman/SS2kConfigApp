/*
 * Copyright (C) 2020  Anthony Doud
 * All rights reserved
 *
 * SPDX-License-Identifier: GPL-2.0-only
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:app_links/app_links.dart';

import 'services/strava_service.dart';
import 'config/env.dart';
//import 'theme/color_schemes.g.dart';
import 'screens/bluetooth_off_screen.dart';
import 'screens/scan_screen.dart';
//import 'theme/theme.dart';
import 'package:json_theme/json_theme.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

void main() async {
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load theme
  final themeStr = await rootBundle.loadString('assets/appainter_theme.json');
  final themeJson = jsonDecode(themeStr);
  final theme = ThemeDecoder.decodeThemeData(themeJson)!;

  // Initialize environment configuration
  Environment.init();

  runApp(SmartSpin2kApp(theme: theme));
}

//
// This widget shows BluetoothOffScreen or
// ScanScreen depending on the adapter state
//
class SmartSpin2kApp extends StatefulWidget {
  final ThemeData theme;
  const SmartSpin2kApp({Key? key, required this.theme}) : super(key: key);

  @override
  State<SmartSpin2kApp> createState() => _SmartSpin2kAppState();
}

class _SmartSpin2kAppState extends State<SmartSpin2kApp> {
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  late AppLinks _appLinks;
  StreamSubscription? _linkSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey = GlobalKey<ScaffoldMessengerState>();

  late StreamSubscription<BluetoothAdapterState> _adapterStateStateSubscription;

  @override
  void initState() {
    super.initState();
    _adapterStateStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      if (mounted) {
        setState(() {});
      }
    });
    _initDeepLinkHandling();
  }

  Future<void> _initDeepLinkHandling() async {
    _appLinks = AppLinks();

    // Handle initial URI if the app was launched with one
    final uri = await _appLinks.getInitialLink();
    if (uri != null) {
      _handleDeepLink(uri);
    }

    // Handle URI when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Deep link error: $err');
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Handling deep link: ${uri.toString()}');
    
    // Handle Strava OAuth callback
    if (uri.host == 'localhost') {
      final code = uri.queryParameters['code'];
      final error = uri.queryParameters['error'];
      
      if (error != null) {
        debugPrint('Strava auth error: $error');
        _scaffoldKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Strava authentication error: $error'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (code != null) {
        // Show loading dialog
        showDialog(
          context: _navigatorKey.currentContext!,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Connecting to Strava...'),
              ],
            ),
          ),
        );

        StravaService.handleAuthCallback(code).then((success) {
          // Close loading dialog
          Navigator.of(_navigatorKey.currentContext!).pop();
          
          if (success && mounted) {
            _scaffoldKey.currentState?.showSnackBar(
              const SnackBar(
                content: Text('Successfully connected to Strava'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );

            // Close the Connected Accounts dialog if it's open
            if (_navigatorKey.currentState?.canPop() ?? false) {
              _navigatorKey.currentState?.pop();
            }
          } else if (mounted) {
            _scaffoldKey.currentState?.showSnackBar(
              const SnackBar(
                content: Text('Failed to connect to Strava'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _adapterStateStateSubscription.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget screen = _adapterState == BluetoothAdapterState.on
        ? const ScanScreen()
        : BluetoothOffScreen(adapterState: _adapterState);

    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        themeMode: ThemeMode.system,
        theme: widget.theme,
        home: screen,
        navigatorObservers: [BluetoothAdapterStateObserver()],
      ),
    );
  }
}

//
// This observer listens for Bluetooth Off and dismisses the DeviceScreen
//
class BluetoothAdapterStateObserver extends NavigatorObserver {
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == '/MainDeviceScreen') {
      // Start listening to Bluetooth state changes when a new route is pushed
      _adapterStateSubscription ??= FlutterBluePlus.adapterState.listen((state) {
        if (state != BluetoothAdapterState.on) {
          // Pop the current route if Bluetooth is off
          navigator?.pop();
        }
      });
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    // Cancel the subscription when the route is popped
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = null;
  }
}
