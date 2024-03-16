import 'package:ff_alarm/globals.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          ElevatedButton(
            onPressed: () {
              Globals.router.go('/lifecycle');
            },
            child: const Text('App Optimierungen'),
          ),
          ElevatedButton(
            onPressed: () {
              Globals.router.go('/notifications');
            },
            child: const Text('Benachrichtigungseinstellungen'),
          ),
        ],
      ),
    );
  }
}
