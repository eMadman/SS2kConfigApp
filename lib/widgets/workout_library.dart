import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/workout/workout_storage.dart';
import '../utils/workout/workout_constants.dart';
import '../utils/workout/workout_parser.dart';

class WorkoutLibrary extends StatelessWidget {
  final bool selectionMode; // true for selection, false for deletion
  final Function(String content)? onWorkoutSelected;
  final Function(String name)? onWorkoutDeleted;

  const WorkoutLibrary({
    Key? key,
    required this.selectionMode,
    this.onWorkoutSelected,
    this.onWorkoutDeleted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: WorkoutStorage.getSavedWorkouts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'No workouts found',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }

        final workouts = snapshot.data!;
        return ListView.builder(
          padding: EdgeInsets.all(WorkoutPadding.standard),
          itemCount: workouts.length,
          itemBuilder: (context, index) {
            final workout = workouts[index];
            return _WorkoutTile(
              name: workout['name'],
              content: workout['content'],
              selectionMode: selectionMode,
              onSelected: onWorkoutSelected,
              onDeleted: onWorkoutDeleted,
            );
          },
        );
      },
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  final String name;
  final String content;
  final bool selectionMode;
  final Function(String content)? onSelected;
  final Function(String name)? onDeleted;

  const _WorkoutTile({
    required this.name,
    required this.content,
    required this.selectionMode,
    this.onSelected,
    this.onDeleted,
  });

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final workoutData = WorkoutParser.parseZwoFile(content);
    int totalTime = 0;
    double normalizedWork = 0;
    double ftpValue = 200; // Default FTP value for thumbnail calculations

    for (var segment in workoutData.segments) {
      totalTime += segment.duration;
      if (segment.isRamp) {
        normalizedWork += segment.duration * ((segment.powerLow + segment.powerHigh) / 2) * ftpValue;
      } else {
        normalizedWork += segment.duration * segment.powerLow * ftpValue;
      }
    }

    final intensityFactor = (normalizedWork / totalTime) / ftpValue;
    final tss = (totalTime * intensityFactor * intensityFactor) / 36;

    return Card(
      margin: EdgeInsets.only(bottom: WorkoutPadding.standard),
      child: InkWell(
        onTap: selectionMode ? () => onSelected?.call(content) : null,
        child: Padding(
          padding: EdgeInsets.all(WorkoutPadding.standard),
          child: Row(
            children: [
              // Thumbnail
              FutureBuilder<String?>(
                future: WorkoutStorage.getWorkoutThumbnail(name),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Container(
                      width: 100,
                      height: 60,
                      color: Colors.grey[300],
                    );
                  }
                  return Image.memory(
                    base64Decode(snapshot.data!),
                    width: 100,
                    height: 60,
                    fit: BoxFit.cover,
                  );
                },
              ),
              SizedBox(width: WorkoutSpacing.medium),
              // Workout name and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: WorkoutSpacing.xsmall),
                    Text(
                      '${_formatDuration(totalTime)} • TSS ${tss.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              // Delete button (only in delete mode)
              if (!selectionMode)
                IconButton(
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Workout'),
                        content: Text('Are you sure you want to delete "$name"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('CANCEL'),
                          ),
                          TextButton(
                            onPressed: () {
                              onDeleted?.call(name);
                              Navigator.pop(context);
                            },
                            child: const Text('DELETE'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
