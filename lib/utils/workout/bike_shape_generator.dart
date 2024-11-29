import 'package:flutter/services.dart' show rootBundle;
import 'dart:math';
import 'package:xml/xml.dart';

class BikeShapeGenerator {
  static List<({double lat, double lon})>? _bikeShapePoints;
  static double? _totalPathDistance;
  static bool _isReversed = false;

  // Load bike shape coordinates from gpx file
  static Future<void> _loadBikeShape() async {
    if (_bikeShapePoints != null) return;

    final content = await rootBundle.loadString('assets/bike_shape.gpx');
    final doc = XmlDocument.parse(content);
    
    _bikeShapePoints = doc.findAllElements('trkpt').map((trkpt) => (
      lat: double.parse(trkpt.getAttribute('lat')!),
      lon: double.parse(trkpt.getAttribute('lon')!)
    )).toList();

    _totalPathDistance = _calculateTotalDistance(_bikeShapePoints!);
  }

  // Calculate total distance of the path in meters
  static double _calculateTotalDistance(List<({double lat, double lon})> points) {
    double totalDistance = 0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += _calculateDistance(points[i], points[i + 1]);
    }
    return totalDistance;
  }

  // Calculate distance between two points in meters using Haversine formula
  static double _calculateDistance(({double lat, double lon}) p1, ({double lat, double lon}) p2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final lat1 = p1.lat * pi / 180;
    final lat2 = p2.lat * pi / 180;
    final deltaLat = (p2.lat - p1.lat) * pi / 180;
    final deltaLon = (p2.lon - p1.lon) * pi / 180;

    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
              cos(lat1) * cos(lat2) *
              sin(deltaLon / 2) * sin(deltaLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  // Find position along path based on distance
  static ({double lat, double lon}) _interpolatePosition(double distance) {
    if (_bikeShapePoints == null || _bikeShapePoints!.isEmpty) {
      throw Exception('Bike shape not loaded');
    }

    // Calculate how many complete path traversals have occurred
    int numReversals = (distance / _totalPathDistance!).floor();
    // Get the remaining distance after complete traversals
    double remainingDistance = distance % _totalPathDistance!;
    
    // If we've reversed an odd number of times, we're going backwards
    _isReversed = numReversals % 2 == 1;
    
    final points = _isReversed ? _bikeShapePoints!.reversed.toList() : _bikeShapePoints!;
    double currentDistance = 0;
    
    for (int i = 0; i < points.length - 1; i++) {
      final segmentDistance = _calculateDistance(points[i], points[i + 1]);
      if (currentDistance + segmentDistance >= remainingDistance) {
        // Interpolate between these points
        final segmentRemainingDistance = remainingDistance - currentDistance;
        final fraction = segmentRemainingDistance / segmentDistance;
        
        return (
          lat: points[i].lat + (points[i + 1].lat - points[i].lat) * fraction,
          lon: points[i].lon + (points[i + 1].lon - points[i].lon) * fraction
        );
      }
      currentDistance += segmentDistance;
    }

    // If we somehow get here (shouldn't happen due to modulo), return last point
    return points.last;
  }

  // Generate track points based on speed and elapsed time
  static Future<List<({double lat, double lon})>> generateBikeShape(List<double> speeds) async {
    await _loadBikeShape();
    
    final positions = <({double lat, double lon})>[];
    double totalDistance = 0;

    for (final speed in speeds) {
      // Calculate distance traveled in this second
      totalDistance += speed; // speed in m/s = distance in meters
      positions.add(_interpolatePosition(totalDistance));
    }

    return positions;
  }
}
