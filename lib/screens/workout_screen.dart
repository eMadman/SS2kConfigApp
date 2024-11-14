import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/workout/workout_parser.dart';
import '../utils/workout/workout_painter.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  List<WorkoutSegment> _segments = [];
  double _maxPower = 0;
  double _totalDuration = 0;
  double _ftpValue = 200; // Default FTP value
  String? _workoutName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSampleWorkout();
    });
  }

  Future<void> _pickAndLoadWorkout() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, //The file extension filter is not working for this library. 
        //allowedExtensions: ['zwo'], // Extension without the dot
        withData: true, // Ensure we get the file data
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // Verify we have the file data
        if (file.bytes == null) {
          throw Exception('Unable to read file data');
        }

        final content = String.fromCharCodes(file.bytes!);
        
        // Basic validation that it's a workout file
        if (!content.trim().contains('<workout_file>')) {
          throw Exception('Invalid workout file format. Expected .zwo file content.');
        }
        
        setState(() {
          _workoutName = file.name;
        });
        
        _loadWorkout(content);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading workout file: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _loadSampleWorkout() {
    // Sample workout XML for testing
    const sampleWorkout = '''
<workout_file>
    <workout>
        <Warmup Duration="600" PowerLow="0.4" PowerHigh="0.75" Cadence="85" />
        <SteadyState Duration="300" Power="0.75" Cadence="90" />
        <IntervalsT Repeat="4" 
                   OnDuration="60" OffDuration="60"
                   OnPower="1.0" OffPower="0.5"
                   CadenceLow="95" CadenceHigh="105" />
        <Ramp Duration="300" PowerLow="0.6" PowerHigh="0.9" />
        <Cooldown Duration="300" PowerLow="0.75" PowerHigh="0.4" />
    </workout>
</workout_file>
''';

    _loadWorkout(sampleWorkout);
  }

  void _loadWorkout(String xmlContent) {
    try {
      final parsedSegments = WorkoutParser.parseZwoFile(xmlContent);
      
      // Calculate max power and total duration
      double maxPower = 0;
      double totalDuration = 0;
      
      for (var segment in parsedSegments) {
        if (segment.isRamp) {
          maxPower = [maxPower, segment.powerLow, segment.powerHigh]
              .reduce((a, b) => a > b ? a : b);
        } else {
          maxPower = [maxPower, segment.powerLow]
              .reduce((a, b) => a > b ? a : b);
        }
        totalDuration += segment.duration;
      }

      // Add some padding to max power for better visualization
      maxPower *= 1.1;
      
      setState(() {
        _segments = parsedSegments;
        _maxPower = maxPower;
        _totalDuration = totalDuration;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading workout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${remainingSeconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    } else {
      return '${remainingSeconds}s';
    }
  }

  Widget _buildWorkoutSummary() {
    if (_segments.isEmpty) return const SizedBox.shrink();

    int totalTime = _totalDuration.round();
    double normalizedWork = 0;
    
    for (var segment in _segments) {
      if (segment.isRamp) {
        // For ramp segments, use average power
        normalizedWork += segment.duration * 
            ((segment.powerLow + segment.powerHigh) / 2) * _ftpValue;
      } else {
        normalizedWork += segment.duration * segment.powerLow * _ftpValue;
      }
    }
    
    // Calculate Training Stress Score (TSS)
    final intensityFactor = (normalizedWork / totalTime) / _ftpValue;
    final tss = (totalTime * intensityFactor * intensityFactor) / 36;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workout Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SummaryItem(
                  label: 'Duration',
                  value: _formatDuration(totalTime),
                  icon: Icons.timer,
                ),
                _SummaryItem(
                  label: 'TSS',
                  value: tss.toStringAsFixed(1),
                  icon: Icons.fitness_center,
                ),
                _SummaryItem(
                  label: 'IF',
                  value: intensityFactor.toStringAsFixed(2),
                  icon: Icons.show_chart,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_workoutName ?? 'Workout'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickAndLoadWorkout,
            tooltip: 'Open .zwo file',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildWorkoutSummary(),
          Expanded(
            child: _segments.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: _totalDuration > 3600 
                              ? constraints.maxWidth * 2 
                              : constraints.maxWidth,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Expanded(
                                  child: CustomPaint(
                                    painter: WorkoutPainter(
                                      segments: _segments,
                                      maxPower: _maxPower,
                                      totalDuration: _totalDuration,
                                      ftpValue: _ftpValue,
                                    ),
                                    child: Container(),
                                  ),
                                ),
                                const SizedBox(height: 20), // Space for time labels
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Duration: ${_formatDuration(_totalDuration.round())}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    const Text('FTP: '),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          suffix: Text('W'),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                        controller: TextEditingController(
                          text: _ftpValue.round().toString(),
                        ),
                        onSubmitted: (value) {
                          setState(() {
                            _ftpValue = double.tryParse(value) ?? _ftpValue;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
