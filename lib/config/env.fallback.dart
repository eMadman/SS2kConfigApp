// This file is used when env.local.dart doesn't exist (like in CI environments)
class Environment {
  static String get stravaClientId => const String.fromEnvironment(
    'STRAVA_CLIENT_ID',
    defaultValue: '',
  );
  
  static String get stravaClientSecret => const String.fromEnvironment(
    'STRAVA_CLIENT_SECRET',
    defaultValue: '',
  );
  
  static bool get hasStravaConfig => 
    stravaClientId.isNotEmpty && stravaClientSecret.isNotEmpty;
}
