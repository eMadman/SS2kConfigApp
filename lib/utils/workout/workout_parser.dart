import 'package:xml/xml.dart';

enum SegmentType {
  steadyState,
  warmup,
  cooldown,
  ramp,
  intervalT,
  freeRide,
  maxEffort
}

class WorkoutData {
  final String? name;
  final List<WorkoutSegment> segments;

  WorkoutData({
    this.name,
    required this.segments,
  });
}

class WorkoutSegment {
  final SegmentType type;
  final int duration; // Duration in seconds
  final double powerLow; // Power as percentage of FTP (0.0 to 1.0)
  final double powerHigh; // For ramp/warmup/cooldown segments
  final bool isRamp; // Whether power changes over time
  final int? repeat; // For intervals
  final int? onDuration; // For intervals
  final int? offDuration; // For intervals
  final double? onPower; // For intervals
  final double? offPower; // For intervals
  final String? cadence; // Optional cadence target
  final String? cadenceLow; // Optional cadence range
  final String? cadenceHigh; // Optional cadence range

  WorkoutSegment({
    required this.type,
    required this.duration,
    required this.powerLow,
    this.powerHigh = 0.0,
    this.isRamp = false,
    this.repeat,
    this.onDuration,
    this.offDuration,
    this.onPower,
    this.offPower,
    this.cadence,
    this.cadenceLow,
    this.cadenceHigh,
  });

  // Helper to get current power at a specific point in the segment
  double getPowerAtTime(int secondsFromStart) {
    if (!isRamp) return powerLow;
    
    final progress = secondsFromStart / duration;
    return powerLow + (powerHigh - powerLow) * progress;
  }

  // Helper to get maximum power in the segment
  double get maxPower {
    if (!isRamp) return powerLow;
    return powerHigh > powerLow ? powerHigh : powerLow;
  }

  // Helper to get minimum power in the segment
  double get minPower {
    if (!isRamp) return powerLow;
    return powerLow < powerHigh ? powerLow : powerHigh;
  }
}

class WorkoutParser {
  static WorkoutData parseZwoFile(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    
    // Find the workout element
    final workoutElements = document.findAllElements('workout');
    if (workoutElements.isEmpty) {
      throw FormatException('No workout element found in .zwo file');
    }
    
    final workoutElement = workoutElements.first;
    
    // Extract workout name
    final nameElements = document.findAllElements('name');
    String? workoutName = nameElements.isNotEmpty ? nameElements.first.text : null;
    
    // Process segments
    final List<WorkoutSegment> segments = [];
    for (var segment in workoutElement.children) {
      if (segment is! XmlElement) continue;

      final type = segment.name.local;
      final parsedSegments = _parseSegment(segment);
      if (parsedSegments != null) {
        segments.addAll(parsedSegments);
      }
    }
    
    return WorkoutData(
      name: workoutName,
      segments: segments,
    );
  }

  static List<WorkoutSegment>? _parseSegment(XmlElement element) {
    final type = element.name.local;
    
    switch (type) {
      case 'SteadyState':
        return [_parseSteadyState(element)];
      
      case 'Warmup':
        return [_parseRampSegment(element, SegmentType.warmup)];
      
      case 'Cooldown':
        return [_parseRampSegment(element, SegmentType.cooldown)];
      
      case 'Ramp':
        return [_parseRampSegment(element, SegmentType.ramp)];
      
      case 'IntervalsT':
        return _parseIntervals(element);
      
      case 'FreeRide':
        return [_parseFreeRide(element)];
      
      case 'MaxEffort':
        return [_parseMaxEffort(element)];
      
      default:
        return null; // Skip unknown segments
    }
  }

  static WorkoutSegment _parseSteadyState(XmlElement element) {
    final duration = int.parse(element.getAttribute('Duration') ?? '0');
    final power = double.parse(element.getAttribute('Power') ?? '0');
    
    return WorkoutSegment(
      type: SegmentType.steadyState,
      duration: duration,
      powerLow: power,
      cadence: element.getAttribute('Cadence'),
      cadenceLow: element.getAttribute('CadenceLow'),
      cadenceHigh: element.getAttribute('CadenceHigh'),
    );
  }

  static WorkoutSegment _parseRampSegment(XmlElement element, SegmentType segmentType) {
    final duration = int.parse(element.getAttribute('Duration') ?? '0');
    final powerLow = double.parse(element.getAttribute('PowerLow') ?? '0');
    final powerHigh = double.parse(element.getAttribute('PowerHigh') ?? '0');
    
    return WorkoutSegment(
      type: segmentType,
      duration: duration,
      powerLow: powerLow,
      powerHigh: powerHigh,
      isRamp: true,
      cadence: element.getAttribute('Cadence'),
      cadenceLow: element.getAttribute('CadenceLow'),
      cadenceHigh: element.getAttribute('CadenceHigh'),
    );
  }

  static List<WorkoutSegment> _parseIntervals(XmlElement element) {
    final repeat = int.parse(element.getAttribute('Repeat') ?? '1');
    final onDuration = int.parse(element.getAttribute('OnDuration') ?? '0');
    final offDuration = int.parse(element.getAttribute('OffDuration') ?? '0');
    final onPower = double.parse(element.getAttribute('OnPower') ?? '0');
    final offPower = double.parse(element.getAttribute('OffPower') ?? '0');
    
    final List<WorkoutSegment> intervals = [];
    
    for (var i = 0; i < repeat; i++) {
      // On interval
      intervals.add(WorkoutSegment(
        type: SegmentType.intervalT,
        duration: onDuration,
        powerLow: onPower,
        onDuration: onDuration,
        offDuration: offDuration,
        onPower: onPower,
        offPower: offPower,
        repeat: repeat,
        cadence: element.getAttribute('Cadence'),
        cadenceLow: element.getAttribute('CadenceLow'),
        cadenceHigh: element.getAttribute('CadenceHigh'),
      ));
      
      // Off interval
      intervals.add(WorkoutSegment(
        type: SegmentType.intervalT,
        duration: offDuration,
        powerLow: offPower,
        onDuration: onDuration,
        offDuration: offDuration,
        onPower: onPower,
        offPower: offPower,
        repeat: repeat,
        cadence: element.getAttribute('Cadence'),
        cadenceLow: element.getAttribute('CadenceLow'),
        cadenceHigh: element.getAttribute('CadenceHigh'),
      ));
    }
    
    return intervals;
  }

  static WorkoutSegment _parseFreeRide(XmlElement element) {
    final duration = int.parse(element.getAttribute('Duration') ?? '0');
    
    return WorkoutSegment(
      type: SegmentType.freeRide,
      duration: duration,
      powerLow: 0.0, // FreeRide has no power target
      cadence: element.getAttribute('Cadence'),
      cadenceLow: element.getAttribute('CadenceLow'),
      cadenceHigh: element.getAttribute('CadenceHigh'),
    );
  }

  static WorkoutSegment _parseMaxEffort(XmlElement element) {
    final duration = int.parse(element.getAttribute('Duration') ?? '0');
    
    return WorkoutSegment(
      type: SegmentType.maxEffort,
      duration: duration,
      powerLow: 1.5, // MaxEffort typically suggests all-out effort (>150% FTP)
      cadence: element.getAttribute('Cadence'),
      cadenceLow: element.getAttribute('CadenceLow'),
      cadenceHigh: element.getAttribute('CadenceHigh'),
    );
  }
}
