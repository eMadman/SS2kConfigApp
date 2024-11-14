import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/workout/workout_parser.dart';
import '../utils/workout/workout_painter.dart';
import '../utils/workout/workout_metrics.dart';
import '../utils/workout/workout_constants.dart';
import '../utils/bledata.dart';
import '../widgets/device_header.dart';
import 'dart:async';

class WorkoutScreen extends StatefulWidget {
  final BluetoothDevice device;
  const WorkoutScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> with SingleTickerProviderStateMixin {
  List<WorkoutSegment> _segments = [];
  double _maxPower = 0;
  double _totalDuration = 0;
  double _ftpValue = 200; // Default FTP value
  String? _workoutName;
  bool _isPlaying = false;
  double _progressPosition = 0;
  Timer? _progressTimer;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late BLEData bleData;
  bool _refreshBlocker = false;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  @override
  void initState() {
    super.initState();
    bleData = BLEDataManager.forDevice(widget.device);
    _fadeController = AnimationController(
      duration: WorkoutDurations.fadeAnimation,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_fadeController);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSampleWorkout();
      rwSubscription();
    });

    // Periodic connection check
    Timer.periodic(const Duration(seconds: 15), (refreshTimer) {
      if (!widget.device.isConnected) {
        try {
          widget.device.connect();
        } catch (e) {
          print("failed to reconnect.");
        }
      } else {
        if (!mounted) {
          refreshTimer.cancel();
        }
      }
    });
  }

  Future<void> rwSubscription() async {
    _connectionStateSubscription = widget.device.connectionState.listen((state) async {
      if (mounted) {
        setState(() {});
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      bleData.isReadingOrWriting.addListener(_rwListener);
    });
  }

  void _rwListener() async {
    if (_refreshBlocker) return;
    _refreshBlocker = true;
    await Future.delayed(const Duration(microseconds: 500));

    if (mounted) {
      setState(() {});
    }
    _refreshBlocker = false;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _progressTimer?.cancel();
    _connectionStateSubscription?.cancel();
    bleData.isReadingOrWriting.removeListener(_rwListener);
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _fadeController.forward();
        _startProgress();
      } else {
        _fadeController.reverse();
        _progressTimer?.cancel();
      }
    });
  }

  Future<void> _pickAndLoadWorkout() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        if (file.bytes == null) {
          throw Exception('Unable to read file data');
        }

        final content = String.fromCharCodes(file.bytes!);
        
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

      maxPower *= 1.1;
      
      setState(() {
        _segments = parsedSegments;
        _maxPower = maxPower;
        _totalDuration = totalDuration;
        _progressPosition = 0;
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

  void _startProgress() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(WorkoutDurations.progressUpdateInterval, (timer) {
      setState(() {
        _progressPosition += WorkoutDurations.progressUpdateInterval.inMilliseconds / (_totalDuration * 1000);
        if (_progressPosition >= 1.0) {
          _progressPosition = 0;
          _isPlaying = false;
          _fadeController.reverse();
          timer.cancel();
        }

        // Update target watts based on current position
        if (_segments.isNotEmpty) {
          double currentTime = _progressPosition * _totalDuration;
          double elapsedTime = 0;
          
          for (var segment in _segments) {
            if (currentTime >= elapsedTime && currentTime < elapsedTime + segment.duration) {
              double segmentProgress = (currentTime - elapsedTime) / segment.duration;
              double targetPower;
              
              if (segment.isRamp) {
                targetPower = segment.powerLow + (segment.powerHigh - segment.powerLow) * segmentProgress;
              } else {
                targetPower = segment.powerLow;
              }
              
              bleData.ftmsData.targetERG = (targetPower * _ftpValue).round();
              break;
            }
            elapsedTime += segment.duration;
          }
        }
      });
    });
  }

  Widget _buildWorkoutSummary() {
    if (_segments.isEmpty) return const SizedBox.shrink();

    int totalTime = _totalDuration.round();
    double normalizedWork = 0;
    
    for (var segment in _segments) {
      if (segment.isRamp) {
        normalizedWork += segment.duration * 
            ((segment.powerLow + segment.powerHigh) / 2) * _ftpValue;
      } else {
        normalizedWork += segment.duration * segment.powerLow * _ftpValue;
      }
    }
    
    final intensityFactor = (normalizedWork / totalTime) / _ftpValue;
    final tss = (totalTime * intensityFactor * intensityFactor) / 36;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        margin: EdgeInsets.all(WorkoutPadding.small),
        child: Padding(
          padding: EdgeInsets.all(WorkoutPadding.standard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workout Summary',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: WorkoutSpacing.xsmall),
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
          Stack(
            children: [
              _buildWorkoutSummary(),
              WorkoutMetrics(
                bleData: bleData,
                fadeAnimation: _fadeAnimation,
              ),
            ],
          ),
          Expanded(
            child: _segments.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final graphPadding = WorkoutPadding.standard;
                      final powerLabelsWidth = 0.0;
                      final availableWidth = (_totalDuration > 3600 
                          ? constraints.maxWidth * 2 
                          : constraints.maxWidth) - (graphPadding * 2) - powerLabelsWidth;
                      final widthScale = availableWidth / _totalDuration;

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: _totalDuration > 3600 
                              ? constraints.maxWidth * 2 
                              : constraints.maxWidth,
                          child: Stack(
                            children: [
                              Padding(
                                padding: EdgeInsets.all(WorkoutPadding.standard),
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
                                    SizedBox(height: WorkoutSpacing.medium),
                                  ],
                                ),
                              ),
                              if (_isPlaying)
                                Positioned(
                                  left: (powerLabelsWidth + graphPadding) + (_progressPosition * _totalDuration * widthScale),
                                  top: WorkoutPadding.standard,
                                  bottom: WorkoutSpacing.medium + WorkoutPadding.standard,
                                  child: Container(
                                    width: WorkoutSizes.progressIndicatorWidth,
                                    color: const Color.fromARGB(255, 0, 0, 0).withOpacity(WorkoutOpacity.segmentBorder),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.all(WorkoutPadding.small),
            child: Column(
              children: [
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                  iconSize: 48,
                  onPressed: _togglePlayPause,
                ),
                SizedBox(height: WorkoutSpacing.small),
                Row(
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
                          width: WorkoutSizes.ftpFieldWidth,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              suffix: const Text('W'),
                              contentPadding: EdgeInsets.symmetric(horizontal: WorkoutPadding.small),
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
        SizedBox(height: WorkoutSpacing.xxsmall),
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
