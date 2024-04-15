import 'package:flutter/material.dart';

class StationPage extends StatefulWidget {
  const StationPage({super.key, required this.stationId});

  final String stationId;

  @override
  State<StationPage> createState() => _StationPageState();
}

class _StationPageState extends State<StationPage> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
