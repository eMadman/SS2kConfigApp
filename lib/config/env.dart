// This file handles environment configuration
import 'env.local.dart' deferred as local_env;

class Environment {
  static const String stravaClientId = String.fromEnvironment('STRAVA_CLIENT_ID');
  static const String stravaClientSecret = String.fromEnvironment('STRAVA_CLIENT_SECRET');

  // Fallback to empty strings if not defined
  static String get effectiveStravaClientId =>
    stravaClientId.isEmpty ? _getLocalEnvValue(() => local_env.Environment.stravaClientId) : stravaClientId;
  
  static String get effectiveStravaClientSecret =>
    stravaClientSecret.isEmpty ? _getLocalEnvValue(() => local_env.Environment.stravaClientSecret) : stravaClientSecret;
  
  static String _getLocalEnvValue(String Function() getter) {
    try {
      // For synchronous access, if the library fails to load or isn't available,
      // we'll catch the error and return empty string
      return getter() ?? '';
    } catch (e) {
      // Ignore errors when local_env is not available (CI builds)
      return '';
    }
  }
  
  static bool get hasStravaConfig =>
    effectiveStravaClientId.isNotEmpty && effectiveStravaClientSecret.isNotEmpty;
}
