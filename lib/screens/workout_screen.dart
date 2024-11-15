import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../utils/workout/workout_parser.dart';
import '../utils/workout/workout_painter.dart';
import '../utils/workout/workout_metrics.dart';
import '../utils/workout/workout_constants.dart';
import '../utils/workout/workout_controller.dart';
import '../utils/workout/workout_storage.dart';
import '../utils/workout/sounds.dart';
import '../utils/workout/fit_file_exporter.dart';
import '../utils/workout/workout_file_manager.dart';
import '../utils/bledata.dart';
import '../widgets/device_header.dart';
import '../widgets/workout_library.dart';

class WorkoutScreen extends StatefulWidget {
  final BluetoothDevice device;
  const WorkoutScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> with TickerProviderStateMixin {
  String? _workoutName;
  String? _currentWorkoutContent;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late BLEData bleData;
  late WorkoutController _workoutController;
  bool _refreshBlocker = false;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  final ScrollController _scrollController = ScrollController();
  double _lastScrollPosition = 0;
  final GlobalKey _workoutGraphKey = GlobalKey();
  
  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;
  static const double previewMinutes = 40;
  static const double playingMinutes = 15;

  // FTP wheel scroll controller
  late final FixedExtentScrollController _ftpScrollController;
  static const int minFTP = 50;
  static const int maxFTP = 500;
  static const int ftpStep = 1;
  late int _selectedFTP;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    bleData = BLEDataManager.forDevice(widget.device);
    _workoutController = WorkoutController(bleData);
    _selectedFTP = _workoutController.ftpValue.round();
    
    _ftpScrollController = FixedExtentScrollController(
      initialItem: (_selectedFTP - minFTP) ~/ ftpStep,
    );
    
    _fadeController = AnimationController(
      duration: WorkoutDurations.fadeAnimation,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_fadeController);

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
      _loadDefaultWorkout();
    });

    _workoutController.addListener(() {
      if (_workoutController.isPlaying) {
        _fadeController.forward();
        _zoomController.forward();
        _updateScrollPosition();
      } else {
        _fadeController.reverse();
        _zoomController.reverse();
        // Check if workout completed naturally (reached the end)
        if (_workoutController.progressPosition >= 1.0) {
          FitFileExporter.showExportDialog(context, _workoutController, _currentWorkoutContent);
        }
      }
      setState(() {
        _workoutName = _workoutController.workoutName;
        if (_selectedFTP != _workoutController.ftpValue.round()) {
          _selectedFTP = _workoutController.ftpValue.round();
          _ftpScrollController.jumpToItem((_selectedFTP - minFTP) ~/ ftpStep);
        }
      });
    });

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

  Future<void> _loadDefaultWorkout() async {
    try {
      final content = await rootBundle.loadString('assets/Anthonys_Mix.zwo');
      _workoutController.loadWorkout(content);
      _currentWorkoutContent = content;
      // Wait for the graph to be rendered
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Generate and save thumbnail for default workout
      final thumbnail = await WorkoutFileManager.captureWorkoutThumbnail(_workoutGraphKey);
      if (thumbnail != null) {
        await WorkoutStorage.updateWorkoutThumbnail(WorkoutStorage.defaultWorkoutName, thumbnail);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading default workout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showStopWorkoutDialog() async {
    final bool? shouldStop = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('End Workout?'),
          content: const Text('Do you want to end your workout?'),
          actions: <Widget>[
            TextButton(
              child: const Text('NO'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('YES'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldStop == true) {
      await _workoutController.stopWorkout();
      FitFileExporter.showExportDialog(context, _workoutController, _currentWorkoutContent);
    }
  }

  void _updateScrollPosition() {
    if (!mounted || !_scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_workoutController.isPlaying && _scrollController.hasClients) {
        final viewportWidth = _scrollController.position.viewportDimension;
        final totalWidth = _scrollController.position.maxScrollExtent + viewportWidth;
        final progressWidth = _workoutController.progressPosition * (totalWidth - (2 * WorkoutPadding.standard));
        
        final targetScroll = progressWidth - (viewportWidth / 2);
        
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
    _ftpScrollController.dispose();
    workoutSoundGenerator.dispose();
    if (_workoutController.progressPosition >= 1.0) {
      WorkoutStorage.clearWorkoutState();
    }
    super.dispose();
  }

  void _showWorkoutLibrary({required bool selectionMode}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.all(WorkoutPadding.standard),
          child: Column(
            children: [
              Text(
                selectionMode ? 'Select Workout' : 'Delete Workout',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: WorkoutSpacing.medium),
              Expanded(
                child: WorkoutLibrary(
                  selectionMode: selectionMode,
                  onWorkoutSelected: (content) {
                    Navigator.pop(context);
                    _workoutController.loadWorkout(content);
                    _currentWorkoutContent = content;
                  },
                  onWorkoutDeleted: (name) async {
                    await WorkoutStorage.deleteWorkout(name);
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
              ),
            ],
          ),
        ),
      ),
    );
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_workoutController.isPlaying)
                IconButton(
                  icon: const Icon(Icons.stop_circle),
                  iconSize: 48,
                  onPressed: () => _showStopWorkoutDialog(),
                ),
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
          Positioned(
            right: WorkoutPadding.standard,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('FTP: '),
                SizedBox(
                  width: 80,
                  height: 220,
                  child: ListWheelScrollView.useDelegate(
                    controller: _ftpScrollController,
                    useMagnifier: true,
                    magnification: 1.3,
                    clipBehavior: Clip.none,
                    overAndUnderCenterOpacity: .2,
                    itemExtent: 40,
                    perspective: 0.01,
                    diameterRatio: 2,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedFTP = minFTP + (index * ftpStep);
                        _workoutController.updateFTP(_selectedFTP.toDouble());
                      });
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: ((maxFTP - minFTP) ~/ ftpStep) + 1,
                      builder: (context, index) {
                        final value = minFTP + (index * ftpStep);
                        return Container(
                          alignment: Alignment.center,
                          child: Text(
                            value.toString(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: value == _selectedFTP ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const Text('W'),
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
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'import':
                  WorkoutFileManager.pickAndLoadWorkout(
                    context: context,
                    workoutController: _workoutController,
                    workoutGraphKey: _workoutGraphKey,
                    onWorkoutLoaded: (content) {
                      _currentWorkoutContent = content;
                    },
                  );
                  break;
                case 'select':
                  _showWorkoutLibrary(selectionMode: true);
                  break;
                case 'delete':
                  _showWorkoutLibrary(selectionMode: false);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_upload),
                    SizedBox(width: 8),
                    Text('Import ZWO'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'select',
                child: Row(
                  children: [
                    Icon(Icons.folder_open),
                    SizedBox(width: 8),
                    Text('Select Workout'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete),
                    SizedBox(width: 8),
                    Text('Delete Workout'),
                  ],
                ),
              ),
            ],
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
                            child: RepaintBoundary(
                              key: _workoutGraphKey,
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
