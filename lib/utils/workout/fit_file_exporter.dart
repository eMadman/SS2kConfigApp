import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'workout_controller.dart';

class FitFileExporter {
  static Future<void> showExportDialog(BuildContext context, WorkoutController workoutController, String? currentWorkoutContent) async {
    final bool? shouldExport = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Export Workout'),
          content: const Text('Would you like to export your workout as a FIT file?'),
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

    if (shouldExport == true) {
      await exportFitFile(context, workoutController);
    }

    // Reset workout position to beginning
    if (currentWorkoutContent != null) {
      workoutController.loadWorkout(currentWorkoutContent);
    }
  }

  static Future<void> exportFitFile(BuildContext context, WorkoutController workoutController) async {
    try {
      final fitData = await workoutController.getLatestFitFile();
      if (fitData == null) {
        throw Exception('No FIT file data available');
      }

      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception('Could not access downloads directory');
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'workout_${timestamp}.fit';
      final file = File('${directory.path}${Platform.pathSeparator}$fileName');
      
      await file.writeAsBytes(fitData);

      if (context.mounted) {
        final bool? shouldShare = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Workout Exported'),
              content: Text('File saved to: ${file.path}\n\nWould you like to share it now?'),
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

        if (shouldShare == true) {
          try {
            await Share.shareXFiles(
              [XFile(file.path),]
            );
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to share file: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }

      // Clear the stored FIT file after successful export
      await workoutController.clearLatestFitFile();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export workout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
