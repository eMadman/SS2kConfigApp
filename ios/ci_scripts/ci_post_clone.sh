#!/bin/sh

# Fail this script if any subcommand fails.
set -e

# The default execution directory of this script is the ci_scripts directory.
cd $CI_PRIMARY_REPOSITORY_PATH # change working directory to the root of your cloned repo.

# Create config directory if it doesn't exist
mkdir -p lib/config

# Create env.local.dart with environment variables from Xcode Cloud
# Use restricted permissions
umask 077
cat > lib/config/env.local.dart << EOL
class Environment {
  static const String stravaClientId = '${STRAVA_CLIENT_ID}';
  static const String stravaClientSecret = '${STRAVA_CLIENT_SECRET}';
  
  static bool get hasStravaConfig => 
    stravaClientId.isNotEmpty && stravaClientSecret.isNotEmpty;
}
EOL

# Install Flutter using git.
git clone https://github.com/flutter/flutter.git --depth 1 -b 3.22.3 $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Install Flutter artifacts for iOS (--ios), or macOS (--macos) platforms.
flutter precache --ios

# Install Flutter dependencies.
flutter pub get

# Install CocoaPods using Homebrew.
HOMEBREW_NO_AUTO_UPDATE=1 # disable homebrew's automatic updates.
brew install cocoapods

# Install CocoaPods dependencies.
cd ios && pod install # run `pod install` in the `ios` directory.

# Clean up env.local.dart (use trap to ensure cleanup even if script fails)
trap 'rm -f $CI_PRIMARY_REPOSITORY_PATH/lib/config/env.local.dart' EXIT

exit 0
