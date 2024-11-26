import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../utils/workout/workout_painter.dart';
import '../utils/workout/workout_metrics.dart';
import '../utils/workout/workout_constants.dart';
import '../utils/workout/workout_controller.dart';
import '../utils/workout/workout_storage.dart';
import '../utils/workout/sounds.dart';
import '../utils/workout/gpx_file_exporter.dart';
import '../utils/workout/workout_file_manager.dart';
import '../utils/workout/workout_tts_settings.dart';
import '../utils/workout/workout_connected_accounts.dart';
import '../utils/bledata.dart';
import '../widgets/workout_library.dart';
import '../widgets/audio_coach_dialog.dart';
import '../utils/workout/workout_text_event_overlay.dart';
import '../utils/workout/workout_controls.dart';
import '../utils/workout/workout_summary.dart';

class WorkoutScreen extends StatefulWidget {
  final BluetoothDevice device;
  const WorkoutScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> with TickerProviderStateMixin {
  String? _workoutName;
  String? _currentWorkoutContent;
  late AnimationController _metricsAndSummaryFadeController;
  late AnimationController _textEventFadeController;
  late Animation<double> _metricsAndSummaryFadeAnimation;
  late Animation<double> _textEventFadeAnimation;
  late BLEData bleData;
  late WorkoutController _workoutController;
  late WorkoutTTSSettings _ttsSettings;
  bool _refreshBlocker = false;
  bool _ttsInitialized = false;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  final ScrollController _scrollController = ScrollController();
  double _lastScrollPosition = 0;
  final GlobalKey _workoutGraphKey = GlobalKey();

  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;

  void _initializeAnimationControllers() {
    _metricsAndSummaryFadeController = AnimationController(
      duration: WorkoutDurations.fadeAnimation,
      vsync: this,
    );
    _textEventFadeController = AnimationController(
      duration: WorkoutDurations.textLinger,  // Total duration including delay and fade
      vsync: this,
    );

    _metricsAndSummaryFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_metricsAndSummaryFadeController);
    _textEventFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_textEventFadeController);

    _zoomController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _zoomAnimation = Tween<double>(
      begin: WorkoutDurations.previewMinutes,
      end: WorkoutDurations.playingMinutes,
    ).animate(CurvedAnimation(
      parent: _zoomController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    bleData = BLEDataManager.forDevice(widget.device);
    _workoutController = WorkoutController(bleData, widget.device);
    _initTTSSettings();
    _initializeAnimationControllers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      rwSubscription();
      if (_workoutController.segments.isEmpty) {
        _loadDefaultWorkout();
      } else if (_workoutController.isPlaying && mounted) {
        // If workout is already playing, forward the animations
        _metricsAndSummaryFadeController.forward();
        _textEventFadeController.forward();
        _zoomController.forward();
      } else {
        _metricsAndSummaryFadeController.animateBack(0);
        _textEventFadeController.animateBack(0);
        _zoomController.animateBack(0);
      }
    });

    _workoutController.addListener(() {
      if (!mounted) return; // Skip animation updates if not mounted

      if (_workoutController.isPlaying) {
        _metricsAndSummaryFadeController.forward();
        _textEventFadeController.forward();
        _zoomController.forward();
        _updateScrollPosition();
      } else {
        _metricsAndSummaryFadeController.reverse();
        _textEventFadeController.reverse();
        _zoomController.reverse();
        // Check if workout completed naturally (reached the end)
        if (_workoutController.progressPosition >= 1.0) {
          //reset progress position
          _workoutController.progressPosition = 0;
          // Add a small delay to ensure the workout end sound plays first
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              GpxFileExporter.showExportDialog(context, _workoutController, _currentWorkoutContent);
            }
          });
        }
      }
      if (mounted) {
        setState(() {
          _workoutName = _workoutController.workoutName;
        });
      }
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

  Future<void> _initTTSSettings() async {
    _ttsSettings = await WorkoutTTSSettings.create();
    if (mounted) {
      setState(() {
        _ttsInitialized = true;
      });
    }
  }

  Future<void> _loadDefaultWorkout() async {
    try {
      final content = await rootBundle.loadString('assets/Anthonys_Mix.zwo');
      _workoutController.loadWorkout(content, isResume: false);
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
      GpxFileExporter.showExportDialog(context, _workoutController, _currentWorkoutContent);
    }
  }

  void _showAudioCoachDialog() {
    showDialog(
      context: context,
      builder: (context) => AudioCoachDialog(ttsSettings: _ttsSettings),
    );
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
    _metricsAndSummaryFadeController.dispose();
    _textEventFadeController.dispose();
    _zoomController.dispose();
    _connectionStateSubscription?.cancel();
    bleData.isReadingOrWriting.removeListener(_rwListener);
    _scrollController.dispose();
    workoutSoundGenerator.dispose();
    _ttsSettings.dispose();
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
                    _workoutController.loadWorkout(content, isResume: false);
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

  @override
  Widget build(BuildContext context) {
    if (!_ttsInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
                case 'audio':
                  _showAudioCoachDialog();
                  break;
                case 'connected_accounts':
                  WorkoutConnectedAccounts.showConnectedAccountsDialog(context);
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
              const PopupMenuItem(
                value: 'audio',
                child: Row(
                  children: [
                    Icon(Icons.record_voice_over),
                    SizedBox(width: 8),
                    Text('Audio Coach'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'connected_accounts',
                child: Row(
                  children: [
                    Icon(Icons.link),
                    SizedBox(width: 8),
                    Text('Connected Accounts'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Stack(
                children: [
                  WorkoutSummary(
                    workoutController: _workoutController,
                    fadeAnimation: _metricsAndSummaryFadeAnimation,
                  ),
                  WorkoutMetrics(
                    bleData: bleData,
                    fadeAnimation: _metricsAndSummaryFadeAnimation,
                    elapsedTime: _workoutController.elapsedSeconds,
                    timeToNextSegment: _workoutController.currentSegmentTimeRemaining,
                    totalDuration: _workoutController.totalDuration,
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
                                                    currentPower: _workoutController.isPlaying
                                                        ? bleData.ftmsData.watts.toDouble()
                                                        : null,
                                                    powerPointsList: _workoutController.getPowerPointsUpToNow(),
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
                                            left: _workoutController.progressPosition *
                                                    (totalWidth - (2 * WorkoutPadding.standard)) +
                                                WorkoutPadding.standard,
                                            top: WorkoutPadding.standard,
                                            bottom: WorkoutSpacing.medium + WorkoutPadding.standard,
                                            child: Container(
                                              width: WorkoutSizes.progressIndicatorWidth,
                                              color: const Color.fromARGB(255, 0, 0, 0)
                                                  .withOpacity(WorkoutOpacity.segmentBorder),
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
              WorkoutControls(
                workoutController: _workoutController,
                onStopWorkout: _showStopWorkoutDialog,
              ),
            ],
          ),
          Positioned.fill(
            child: WorkoutTextEventOverlay(
              currentSegment: _workoutController.currentSegment,
              secondsIntoSegment: _workoutController.currentSegmentElapsedSeconds,
              fadeAnimation: _textEventFadeAnimation,
              ttsSettings: _ttsSettings,
            ),
          ),
        ],
      ),
    );
  }
}
