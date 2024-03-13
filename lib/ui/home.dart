import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:flutter/material.dart';
import 'dart:io';

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
                try {
                  Globals.loggedIn = true;
                  await Request('test', {"token": Globals.prefs.getString("fcm_token"), "ios": Platform.isIOS}).emit(true);
                } catch (e, s) {
                  if (e is AckError) {
                    print('Failed to send test request: ${e.errorMessage} (${e.errorCode})');
                  } else {
                    print('Failed to send test request: $e $s');
                  }
                }
              },
              child: const Text('Alarmieren'),
            ),
          ],
        ),
      ),
    );
  }
}
