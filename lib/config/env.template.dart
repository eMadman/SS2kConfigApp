/*
 * Environment Configuration Guide
 * -----------------------------
 * 
 * This file serves as a template for setting up environment variables in different contexts:
 * 
 * 1. Local Development:
 *    - Copy this file to 'env.local.dart'
 *    - Replace the placeholder values with your actual Strava API credentials
 *    - The app will automatically use these values when running locally
 * 
 * 2. CI/CD Builds (GitHub Actions & Xcode Cloud):
 *    - The CI pipeline will automatically create env.local.dart using repository secrets
 *    - No manual action required
 * 
 * Switching Between Environments:
 * -----------------------------
 * A. For Local Development:
 *    1. Create env.local.dart from this template
 *    2. Add your Strava credentials
 *    3. Run the app normally: flutter run
 * 
 * B. For Testing CI Environment Locally:
 *    Run the app with dart-define parameters:
 *    flutter run --dart-define=STRAVA_CLIENT_ID=your_id --dart-define=STRAVA_CLIENT_SECRET=your_secret
 * 
 * Security Notes:
 * -------------
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
