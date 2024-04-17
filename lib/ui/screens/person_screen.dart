import 'package:flutter/material.dart';

class PersonPage extends StatefulWidget {
  const PersonPage({super.key, required this.personId});

  final String personId;

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
