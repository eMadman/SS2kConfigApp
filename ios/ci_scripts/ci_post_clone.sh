#!/bin/sh

# Fail this script if any subcommand fails.
set -e

# The default execution directory of this script is the ci_scripts directory.
cd $CI_PRIMARY_REPOSITORY_PATH # change working directory to the root of your cloned repo.

# Export environment variables
export STRAVA_CLIENT_ID=$STRAVA_CLIENT_ID
export STRAVA_CLIENT_SECRET=$STRAVA_CLIENT_SECRET

# Install Flutter using git.
git clone https://github.com/flutter/flutter.git --depth 1 -b 3.22.3 $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Install Flutter artifacts for iOS (--ios), or macOS (--macos) platforms.
flutter precache --ios

# Install Flutter dependencies
flutter pub get

# Build the Flutter app with the extra arguments from environment variable
flutter build ios --release --no-codesign $FLUTTER_EXTRA_ARGS

# Install CocoaPods using Homebrew.
HOMEBREW_NO_AUTO_UPDATE=1 # disable homebrew's automatic updates.
brew install cocoapods

# Install CocoaPods dependencies.
cd ios && pod install # run `pod install` in the `ios` directory.

exit 0
