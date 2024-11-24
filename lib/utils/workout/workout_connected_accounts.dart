import 'package:flutter/material.dart';
import '../../services/strava_service.dart';

class WorkoutConnectedAccounts {
  static Widget buildConnectedAccountsMenu(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Connected Accounts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<bool>(
                stream: Stream.periodic(const Duration(seconds: 1))
                  .asyncMap((_) => StravaService.isAuthenticated()),
                builder: (context, snapshot) {
                  final isConnected = snapshot.data ?? false;
                  
                  return ListTile(
                    leading: const Icon(Icons.directions_bike),
                    title: const Text('Strava'),
                    subtitle: Text(isConnected ? 'Connected' : 'Not connected'),
                    trailing: isConnected
                      ? TextButton.icon(
                          icon: const Icon(Icons.link_off),
                          label: const Text('Disconnect'),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Disconnect Strava'),
                                content: const Text('Are you sure you want to disconnect your Strava account?'),
                                actions: [
                                  TextButton(
                                    child: const Text('CANCEL'),
                                    onPressed: () => Navigator.of(context).pop(false),
                                  ),
                                  TextButton(
                                    child: const Text('DISCONNECT'),
                                    onPressed: () => Navigator.of(context).pop(true),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              await StravaService.clearTokens();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Strava account disconnected'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                setState(() {}); // Refresh the UI
                              }
                            }
                          },
                        )
                      : null,
                    onTap: () async {
                      if (!isConnected) {
                        await StravaService.authenticate(context);
                      }
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static void showConnectedAccountsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: buildConnectedAccountsMenu(context),
      ),
    );
  }
}
