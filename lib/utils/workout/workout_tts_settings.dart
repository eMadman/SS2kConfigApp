import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class WorkoutTTSSettings {
  static const String _enabledKey = 'workout_tts_enabled';
  static const String _voiceKey = 'workout_tts_voice';
  static const String _volumeKey = 'workout_tts_volume';
  static const String _pitchKey = 'workout_tts_pitch';
  static const String _rateKey = 'workout_tts_rate';

  final FlutterTts _flutterTts = FlutterTts();
  final SharedPreferences _prefs;
  final Set<String> _spokenMessages = {};
  
  bool _enabled;
  String? _voice;
  double _volume;
  double _pitch;
  double _rate;

  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  WorkoutTTSSettings._(this._prefs)
      : _enabled = _prefs.getBool(_enabledKey) ?? true,
        _voice = _prefs.getString(_voiceKey),
        _volume = _prefs.getDouble(_volumeKey) ?? 1.0,
        _pitch = _prefs.getDouble(_pitchKey) ?? 1.0,
        _rate = _prefs.getDouble(_rateKey) ?? 0.5;

  static Future<WorkoutTTSSettings> create() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = WorkoutTTSSettings._(prefs);
    await settings._initTts();
    return settings;
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      if (isIOS) {
        await _flutterTts.setIosAudioCategory(
            IosTextToSpeechAudioCategory.ambient,
            [
              IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            ],
            IosTextToSpeechAudioMode.voicePrompt);
      }
      await _flutterTts.setSpeechRate(_rate);
      await _flutterTts.setVolume(_volume);
      await _flutterTts.setPitch(_pitch);
      if (_voice != null) {
        final voices = await _flutterTts.getVoices;
        final selectedVoice = (voices as List).firstWhere(
          (voice) => voice['name'] == _voice,
          orElse: () => null,
        );
        if (selectedVoice != null) {
          await _flutterTts.setVoice(selectedVoice);
        }
      }
    } catch (e) {
      print('Error initializing TTS: $e');
    }
  }

  bool get enabled => _enabled;
  String? get voice => _voice;
  double get volume => _volume;
  double get pitch => _pitch;
  double get rate => _rate;

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _prefs.setBool(_enabledKey, value);
    if (!value) {
      await _flutterTts.stop();
    }
  }

  Future<void> setVoice(String value) async {
    try {
      final voices = await _flutterTts.getVoices;
      final selectedVoice = (voices as List).firstWhere(
        (voice) => voice['name'] == value,
        orElse: () => null,
      );
      
      if (selectedVoice != null) {
        await _flutterTts.setVoice(selectedVoice);
        _voice = value;
        await _prefs.setString(_voiceKey, value);
        
        // Test the voice change immediately
        await speakTest("Voice changed to $value");
      } else {
        print('Selected voice not found in available voices');
      }
    } catch (e) {
      print('Error setting voice: $e');
    }
  }

  Future<void> setVolume(double value) async {
    _volume = value;
    await _prefs.setDouble(_volumeKey, value);
    await _flutterTts.setVolume(value);
  }

  Future<void> setPitch(double value) async {
    _pitch = value;
    await _prefs.setDouble(_pitchKey, value);
    await _flutterTts.setPitch(value);
  }

  Future<void> setRate(double value) async {
    _rate = value;
    await _prefs.setDouble(_rateKey, value);
    await _flutterTts.setSpeechRate(value);
  }

  Future<List<String>> getAvailableVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      return (voices as List)
          .map((voice) => voice['name'] as String)
          .toList();
    } catch (e) {
      print('Error getting available voices: $e');
      return [];
    }
  }

  Future<void> speak(String message) async {
    if (!_enabled || _spokenMessages.contains(message)) return;
    
    try {
      await _flutterTts.speak(message);
      _spokenMessages.add(message);
    } catch (e) {
      print('Error speaking message: $e');
    }
  }

  Future<void> speakTest(String message) async {
    if (!_enabled) return;
    
    try {
      await stop(); // Stop any current speech first
      await _flutterTts.speak(message);
    } catch (e) {
      print('Error in test speech: $e');
    }
  }

  void clearSpokenMessages() {
    _spokenMessages.clear();
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  void dispose() {
    _flutterTts.stop();
  }
}
