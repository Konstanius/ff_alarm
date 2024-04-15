import 'package:flutter/material.dart';

class UnitPage extends StatefulWidget {
  const UnitPage({super.key, required this.unitId});

  final String unitId;

  @override
  State<UnitPage> createState() => _UnitPageState();
}

class _UnitPageState extends State<UnitPage> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
