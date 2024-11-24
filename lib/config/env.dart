// This file handles environment configuration
import 'env.local.dart';

// Re-export Environment class from env.local.dart
export 'env.local.dart';

// Note: During CI builds, env.local.dart is automatically created with values from repository secrets.
// For local development, copy env.template.dart to env.local.dart and add your credentials.
// See env.template.dart for detailed instructions on environment setup.
