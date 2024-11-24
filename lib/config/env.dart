// This file handles environment configuration
import 'env.local.dart' as local_env;

class Environment {
  // First try dart-define values (CI builds)
  static const String stravaClientId = String.fromEnvironment(
    'STRAVA_CLIENT_ID',
    // If dart-define not found, use local env
    defaultValue: local_env.Environment.stravaClientId
  );
  
  static const String stravaClientSecret = String.fromEnvironment(
    'STRAVA_CLIENT_SECRET',
    // If dart-define not found, use local env
    defaultValue: local_env.Environment.stravaClientSecret
  );
  
  static bool get hasStravaConfig => 
    stravaClientId.isNotEmpty && stravaClientSecret.isNotEmpty;
}
