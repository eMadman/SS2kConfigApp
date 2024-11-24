// This file handles both local development and CI environments
import 'env.fallback.dart' as fallback;
import 'env.local.dart' as local_env;

class Environment {
  static bool _useLocalEnv = false;
  static bool _initialized = false;

  /// Initialize the environment configuration
  static void init() {
    if (_initialized) return;
    
    try {
      // Try to access local environment to see if it exists
      local_env.Environment.stravaClientId;
      _useLocalEnv = true;
    } catch (_) {
      _useLocalEnv = false;
    }
    
    _initialized = true;
  }

  static String get stravaClientId {
    // First try to get from dart-define (CI environment)
    var value = const String.fromEnvironment('STRAVA_CLIENT_ID');
    if (value.isNotEmpty) {
      return value;
    }
    
    // If local env is available and loaded, use it
    if (_useLocalEnv) {
      return local_env.Environment.stravaClientId;
    }
    
    // Fallback to empty string if no configuration is found
    return fallback.Environment.stravaClientId;
  }
  
  static String get stravaClientSecret {
    // First try to get from dart-define (CI environment)
    var value = const String.fromEnvironment('STRAVA_CLIENT_SECRET');
    if (value.isNotEmpty) {
      return value;
    }
    
    // If local env is available and loaded, use it
    if (_useLocalEnv) {
      return local_env.Environment.stravaClientSecret;
    }
    
    // Fallback to empty string if no configuration is found
    return fallback.Environment.stravaClientSecret;
  }
  
  static bool get hasStravaConfig => 
    stravaClientId.isNotEmpty && stravaClientSecret.isNotEmpty;
}
