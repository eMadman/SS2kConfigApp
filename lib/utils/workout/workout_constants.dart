import 'package:flutter/material.dart';

/// Padding and spacing constants used throughout the workout UI
class WorkoutPadding {
  /// Standard edge padding for cards and containers
  static const double standard = 16.0;
  
  /// Small padding for tight spaces
  static const double small = 8.0;
  
  /// Horizontal padding for metric boxes
  static const double metricHorizontal = 8.0;
}

/// Vertical spacing constants
class WorkoutSpacing {
  /// Extra extra small vertical spacing
  static const double xxsmall = 4.0;
  
  /// Extra small vertical spacing
  static const double xsmall = 8.0;
  
  /// Small vertical spacing
  static const double small = 16.0;
  
  /// Medium vertical spacing
  static const double medium = 20.0;
}

/// Size constants for various UI elements
class WorkoutSizes {
  /// Width of the FTP input field
  static const double ftpFieldWidth = 80.0;
  
  /// Width of the progress indicator line
  static const double progressIndicatorWidth = 3.0;
  
  /// Height of the cadence indicator
  static const double cadenceIndicatorHeight = 20.0;
}

/// Font size constants
class WorkoutFontSizes {
  /// Font size for grid labels and small text
  static const double small = 10.0;
}

/// Duration constants for animations and intervals
class WorkoutDurations {
  /// Duration for fade animations
  static const Duration fadeAnimation = Duration(milliseconds: 500);
  
  /// Interval for progress updates
  static const Duration progressUpdateInterval = Duration(milliseconds: 100);
}

/// Grid constants for the workout graph
class WorkoutGrid {
  /// Interval for power grid lines (in watts)
  static const double powerLineInterval = 50.0;
  
  /// Interval for time grid lines (in seconds)
  static const double timeLineInterval = 300.0; // 5 minutes
}

/// Opacity values for various UI elements
class WorkoutOpacity {
  /// Opacity for segment colors
  static const double segmentColor = 0.7;
  
  /// Opacity for grid lines
  static const double gridLines = 0.5;
  
  /// Opacity for segment borders
  static const double segmentBorder = 0.3;
}

/// Stroke width constants for lines and borders
class WorkoutStroke {
  /// Width for standard borders
  static const double border = 1.0;
  
  /// Width for cadence indicator
  static const double cadenceIndicator = 2.0;
}
