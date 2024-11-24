// This file provides fallback values for environment configuration
class Environment {
  static const String stravaClientId = String.fromEnvironment('STRAVA_CLIENT_ID', defaultValue: '');
  static const String stravaClientSecret = String.fromEnvironment('STRAVA_CLIENT_SECRET', defaultValue: '');
  
  static bool get hasStravaConfig => 
    stravaClientId.isNotEmpty && stravaClientSecret.isNotEmpty;
}
