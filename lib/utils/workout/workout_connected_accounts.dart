import 'package:flutter/material.dart';

class WorkoutConnectedAccounts {
  static Widget buildConnectedAccountsMenu(BuildContext context) {
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
          ListTile(
            leading: const Icon(Icons.directions_bike),
            title: const Text('Strava'),
            subtitle: const Text('Not connected'),
            onTap: () {
              // Strava connection functionality will be implemented in future task
              Navigator.pop(context);
            },
          ),
        ],
      ),
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
