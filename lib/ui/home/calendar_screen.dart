import 'package:flutter/material.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.badge, required this.setActionWidgets});

  final ValueNotifier<int> badge;
  final void Function(List<Widget>) setActionWidgets;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  @override
  void initState() {
    super.initState();
    widget.setActionWidgets(<Widget>[]);
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
