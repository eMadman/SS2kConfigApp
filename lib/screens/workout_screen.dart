import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/workout/workout_parser.dart';
import '../utils/workout/workout_painter.dart';
import '../utils/workout/workout_metrics.dart';
import '../utils/workout/workout_constants.dart';
import '../utils/workout/workout_controller.dart';
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
  String? _workoutName;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late BLEData bleData;
  late WorkoutController _workoutController;
  bool _refreshBlocker = false;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  final ScrollController _scrollController = ScrollController();
  double _lastScrollPosition = 0;

  @override
  void initState() {
    super.initState();
    bleData = BLEDataManager.forDevice(widget.device);
    _workoutController = WorkoutController(bleData);
    _fadeController = AnimationController(
      duration: WorkoutDurations.fadeAnimation,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_fadeController);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSampleWorkout();
      rwSubscription();
    });

    _workoutController.addListener(() {
      if (_workoutController.isPlaying) {
        _fadeController.forward();
        _updateScrollPosition();
      } else {
        _fadeController.reverse();
      }
      setState(() {
        _workoutName = _workoutController.workoutName;
      });
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

  void _updateScrollPosition() {
    if (!mounted || !_scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_workoutController.isPlaying && _scrollController.hasClients) {
        final viewportWidth = _scrollController.position.viewportDimension;
        final totalWidth = _scrollController.position.maxScrollExtent + viewportWidth;
        final progressWidth = totalWidth * _workoutController.progressPosition;
        
        // Calculate the target scroll position to keep the indicator centered
        final targetScroll = progressWidth - (viewportWidth / 2);
        
        // Only scroll if we've moved enough to warrant it
        if ((targetScroll - _lastScrollPosition).abs() > 1.0) {
          _scrollController.animateTo(
            targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
          _lastScrollPosition = targetScroll;
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
    _connectionStateSubscription?.cancel();
    bleData.isReadingOrWriting.removeListener(_rwListener);
    _workoutController.dispose();
    _scrollController.dispose();
    super.dispose();
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
        
        _workoutController.loadWorkout(content);
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
    <name>Sample Workout</name>
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

    _workoutController.loadWorkout(sampleWorkout);
  }

  Widget _buildWorkoutSummary() {
    if (_workoutController.segments.isEmpty) return const SizedBox.shrink();

    int totalTime = _workoutController.totalDuration.round();
    double normalizedWork = 0;
    
    for (var segment in _workoutController.segments) {
      if (segment.isRamp) {
        normalizedWork += segment.duration * 
            ((segment.powerLow + segment.powerHigh) / 2) * _workoutController.ftpValue;
      } else {
        normalizedWork += segment.duration * segment.powerLow * _workoutController.ftpValue;
      }
    }
    
    final intensityFactor = (normalizedWork / totalTime) / _workoutController.ftpValue;
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
                    value: _workoutController.formatDuration(totalTime),
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

  Widget _buildControls() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: WorkoutPadding.small),
      child: Column(
        children: [
          // FTP Input at the top
          Padding(
            padding: EdgeInsets.symmetric(horizontal: WorkoutPadding.standard),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
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
                      text: _workoutController.ftpValue.round().toString(),
                    ),
                    onSubmitted: (value) => _workoutController.updateFTP(double.tryParse(value)),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: WorkoutSpacing.medium),
          // Centered play controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(_workoutController.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                iconSize: 48,
                onPressed: _workoutController.togglePlayPause,
              ),
              if (_workoutController.isPlaying)
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  iconSize: 48,
                  onPressed: _workoutController.skipToNextSegment,
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_workoutName ?? ''),
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
                elapsedTime: _workoutController.elapsedSeconds,
                timeToNextSegment: _workoutController.currentSegmentTimeRemaining,
              ),
            ],
          ),
          Expanded(
            child: _workoutController.segments.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final graphPadding = WorkoutPadding.standard;
                      final powerLabelsWidth = 0.0;
                      final availableWidth = (_workoutController.totalDuration > 3600 
                          ? constraints.maxWidth * 2 
                          : constraints.maxWidth) - (graphPadding * 2) - powerLabelsWidth;
                      final widthScale = availableWidth / _workoutController.totalDuration;

                      return SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: _workoutController.totalDuration > 3600 
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
                                          segments: _workoutController.segments,
                                          maxPower: _workoutController.maxPower,
                                          totalDuration: _workoutController.totalDuration,
                                          ftpValue: _workoutController.ftpValue,
                                          currentProgress: _workoutController.progressPosition,
                                          actualPowerPoints: _workoutController.actualPowerPoints,
                                          currentPower: _workoutController.isPlaying ? bleData.ftmsData.watts / _workoutController.ftpValue : null,
                                        ),
                                        child: Container(),
                                      ),
                                    ),
                                    SizedBox(height: WorkoutSpacing.medium),
                                  ],
                                ),
                              ),
                              if (_workoutController.isPlaying)
                                Positioned(
                                  left: (powerLabelsWidth + graphPadding) + (_workoutController.progressPosition * _workoutController.totalDuration * widthScale),
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
          _buildControls(),
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
