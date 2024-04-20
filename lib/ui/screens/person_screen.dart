import 'package:ff_alarm/data/models/person.dart';
import 'package:flutter/material.dart';

class PersonPage extends StatefulWidget {
  const PersonPage({super.key, required this.person});

  final Person person;

  @override
  State<PersonPage> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text('Person'),
      ),
      body: const Placeholder(),
    );
  }
}
