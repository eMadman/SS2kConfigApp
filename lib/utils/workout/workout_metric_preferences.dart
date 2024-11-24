import 'package:shared_preferences/shared_preferences.dart';

class WorkoutMetricPreferences {
  static const String _metricOrderKey = 'workout_metric_order';

  static Future<List<String>> getMetricOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? savedOrder = prefs.getStringList(_metricOrderKey);
      
      if (savedOrder != null && savedOrder.isNotEmpty) {
        return savedOrder;
      }
    } catch (e) {
      print('Error loading metric order: $e');
    }
    return defaultMetricOrder;
  }

  static Future<void> saveMetricOrder(List<String> order) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_metricOrderKey, order);
    } catch (e) {
      print('Error saving metric order: $e');
    }
  }

  // Default order of metrics
  static const List<String> defaultMetricOrder = [
    'Elapsed Time',
    'Power',
    'Target',
    'Cadence',
    'Heart Rate',
    'Next Block',
    'Remaining Time',
  ];
}
