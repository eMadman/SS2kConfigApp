import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../utils/workout/workout_parser.dart';
import '../utils/workout/workout_painter.dart';
import '../utils/workout/workout_metrics.dart';
import '../utils/workout/workout_constants.dart';
import '../utils/workout/workout_controller.dart';
import '../utils/workout/workout_storage.dart';
import '../utils/workout/sounds.dart';
import '../utils/bledata.dart';
import '../widgets/device_header.dart';
import 'dart:async';

class WorkoutScreen extends StatefulWidget {
  final BluetoothDevice device;
  const WorkoutScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

// Changed to TickerProviderStateMixin for multiple animation controllers
class _WorkoutScreenState extends State<WorkoutScreen> with TickerProviderStateMixin {
  String? _workoutName;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late BLEData bleData;
  late WorkoutController _workoutController;
  bool _refreshBlocker = false;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  final ScrollController _scrollController = ScrollController();
  double _lastScrollPosition = 0;
  late TextEditingController _ftpController;
  
  // Animation for workout width
  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;
  static const double previewMinutes = 40;
  static const double playingMinutes = 15;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    bleData = BLEDataManager.forDevice(widget.device);
    _workoutController = WorkoutController(bleData);
    _ftpController = TextEditingController(text: _workoutController.ftpValue.round().toString());
    
    // Initialize fade animation
    _fadeController = AnimationController(
      duration: WorkoutDurations.fadeAnimation,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_fadeController);

    // Initialize zoom animation
    _zoomController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _zoomAnimation = Tween<double>(
      begin: previewMinutes,
      end: playingMinutes,
    ).animate(CurvedAnimation(
      parent: _zoomController,
      curve: Curves.easeInOut,
    ));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      rwSubscription();
    });

    _workoutController.addListener(() {
      if (_workoutController.isPlaying) {
        _fadeController.forward();
        _zoomController.forward();
        _updateScrollPosition();
      } else {
        _fadeController.reverse();
        _zoomController.reverse();
      }
      setState(() {
        _workoutName = _workoutController.workoutName;
        // Update FTP controller when FTP changes and not playing
        if (!_workoutController.isPlaying && 
            _ftpController.text != _workoutController.ftpValue.round().toString()) {
          _ftpController.text = _workoutController.ftpValue.round().toString();
        }
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
        // Calculate progress width using the same scale as the CustomPaint
        final progressWidth = _workoutController.progressPosition * (totalWidth - (2 * WorkoutPadding.standard));
        
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
    WakelockPlus.disable();
    _fadeController.dispose();
    _zoomController.dispose();
    _connectionStateSubscription?.cancel();
    bleData.isReadingOrWriting.removeListener(_rwListener);
    _workoutController.dispose();
    _scrollController.dispose();
    _ftpController.dispose();
    workoutSoundGenerator.dispose();
    // Clear workout state if it's completed
    if (_workoutController.progressPosition >= 1.0) {
      WorkoutStorage.clearWorkoutState();
    }
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Centered play controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(_workoutController.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                iconSize: 48,
                onPressed: () {
                  if (!_workoutController.isPlaying) {
                    workoutSoundGenerator.playButtonSound();
                  }
                  _workoutController.togglePlayPause();
                },
              ),
              if (_workoutController.isPlaying)
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  iconSize: 48,
                  onPressed: _workoutController.skipToNextSegment,
                ),
            ],
          ),
          // FTP Input positioned on the right
          Positioned(
            right: WorkoutPadding.standard,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('FTP: '),
                SizedBox(
                  width: WorkoutSizes.ftpFieldWidth,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      suffix: const Text('W'),
                      contentPadding: EdgeInsets.symmetric(horizontal: WorkoutPadding.small),
                      enabled: !_workoutController.isPlaying,
                      hintText: _workoutController.isPlaying ? 'Pause to edit' : null,
                    ),
                    enabled: !_workoutController.isPlaying,
                    controller: _ftpController,
                    onSubmitted: (value) => _workoutController.updateFTP(double.tryParse(value)),
                  ),
                ),
              ],
            ),
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
                : AnimatedBuilder(
                    animation: _zoomAnimation,
                    builder: (context, child) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final minutesWidth = constraints.maxWidth / _zoomAnimation.value;
                          final totalWidth = _workoutController.totalDuration / 60 * minutesWidth;

                          return SingleChildScrollView(
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: totalWidth,
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
                                              currentPower: _workoutController.isPlaying ? bleData.ftmsData.watts.toDouble() : null,
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
                                      left: _workoutController.progressPosition * (totalWidth - (2 * WorkoutPadding.standard)) + WorkoutPadding.standard,
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
