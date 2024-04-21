import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/ui/screens/station_screen.dart';
import 'package:flutter/material.dart';

class PersonPicker extends StatefulWidget {
  const PersonPicker({
    super.key,
    required this.persons,
  });

  final List<Person> persons;

  @override
  State<PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends State<PersonPicker> {
  @override
  void initState() {
    super.initState();
    widget.persons.sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Person auswählen'),
      ),
      body: ListView.builder(
        itemCount: widget.persons.length,
        padding: const EdgeInsets.all(8),
        itemBuilder: (context, index) {
          final person = widget.persons[index];
          return StationPageState.personDisplayCard(
            person: person,
            onTap: (person) {
              Navigator.of(context).pop(person);
            },
            now: now,
          );
        },
      ),
    );
  }
}
