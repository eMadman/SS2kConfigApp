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
              FutureBuilder<bool>(
                future: StravaService.isAuthenticated(),
                builder: (context, snapshot) {
                  final isConnected = snapshot.data ?? false;
                  
                  return ListTile(
                    leading: const Icon(Icons.directions_bike),
                    title: const Text('Strava'),
                    subtitle: Text(isConnected ? 'Connected' : 'Not connected'),
                    trailing: isConnected
                      ? IconButton(
                          icon: const Icon(Icons.logout),
                          onPressed: () async {
                            await StravaService.clearTokens();
                            setState(() {});
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
