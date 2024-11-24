// Copy this file to env.local.dart and replace the values with your Strava API credentials
// DO NOT commit env.local.dart to version control
class Environment {
  static const String stravaClientId = 'your_strava_client_id_here';
  static const String stravaClientSecret = 'your_strava_client_secret_here';
  
  static bool get hasStravaConfig => 
    stravaClientId.isNotEmpty && stravaClientSecret.isNotEmpty;
}

/* Instructions for setting up Strava API credentials:
 * 1. Go to https://www.strava.com/settings/api
 * 2. Create a new application
 * 3. Copy the Client ID and Client Secret
 * 4. Create a copy of this file named env.local.dart
 * 5. Replace the placeholder values with your actual credentials
 * 
 * For CI/CD:
 * - GitHub Actions: Add STRAVA_CLIENT_ID and STRAVA_CLIENT_SECRET to your repository secrets
 * - Xcode Cloud: Add these same variables in App Store Connect > Your App > Xcode Cloud
 */
