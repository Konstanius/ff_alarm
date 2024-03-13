import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/notifications/awn_init.dart';
import 'package:flutter/material.dart';

class FFAlarmApp extends StatelessWidget {
  const FFAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FF Alarm',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: const ColorScheme.light().copyWith(
          primary: Colors.blue,
          onPrimary: Colors.white,
          secondary: Colors.blue,
          onSecondary: Colors.white,
        ),
      ),
      routerConfig: Globals.router,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Globals.appStarted = true;
    Globals.fastStartBypass = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FF Alarm'),
      ),
      body: Center(
        child: Column(
          children: [
            const Text('Startbildschirm'),
            ElevatedButton(
              onPressed: () async {
                sendTestAlarm();
              },
              child: const Text('Alarmieren'),
            ),
          ],
        ),
      ),
    );
  }
}
