/*
 * Environment Configuration Guide
 * -----------------------------
 * 
 * This template shows how to set up environment variables for different contexts:
 * 
 * 1. Local Development:
 *    Option A - Create env.local.dart:
 *    - Copy this file to 'env.local.dart'
 *    - Replace the placeholder values with your actual Strava API credentials
 * 
 *    Option B - Use dart-define:
 *    - Run Flutter with environment variables:
 *      flutter run --dart-define=STRAVA_CLIENT_ID=your_id --dart-define=STRAVA_CLIENT_SECRET=your_secret
 * 
 * 2. CI/CD Environment Setup:
 *    - GitHub Actions: Already configured to use repository secrets
 *    - Xcode Cloud: Add to build settings:
 *      OTHER_ARGS="--dart-define=STRAVA_CLIENT_ID=${STRAVA_CLIENT_ID} --dart-define=STRAVA_CLIENT_SECRET=${STRAVA_CLIENT_SECRET}"
 * 
 * Security Notes:
 * - Never commit env.local.dart to version control
 * - Keep your API credentials secure
 * - Use repository secrets in GitHub/Xcode for CI/CD builds
 */

class Environment {
  static const String stravaClientId = 'your_strava_client_id_here';
  static const String stravaClientSecret = 'your_strava_client_secret_here';
  
  static bool get hasStravaConfig => 
    stravaClientId.isNotEmpty && stravaClientSecret.isNotEmpty;
}
