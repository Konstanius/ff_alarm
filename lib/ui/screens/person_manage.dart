import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/ui/utils/dialogs.dart';
import 'package:flutter/material.dart';

class PersonManageScreen extends StatefulWidget {
  const PersonManageScreen({super.key, this.person, required this.stationId});

  final Person? person;
  final String stationId;

  @override
  State<PersonManageScreen> createState() => _PersonManageScreenState();
}

class _PersonManageScreenState extends State<PersonManageScreen> {
  late DateTime birthday;
  late DateTime onInit;

  late TextEditingController firstNameController;
  late TextEditingController lastNameController;

  late List<Qualification> qualifications;

  @override
  void initState() {
    super.initState();
    if (widget.person != null) {
      birthday = widget.person!.birthday;

      firstNameController = TextEditingController(text: widget.person!.firstName);
      lastNameController = TextEditingController(text: widget.person!.lastName);

      qualifications = [];
      for (var qualification in widget.person!.qualifications) {
        qualifications.add(Qualification.fromString(qualification.toString()));
      }
    } else {
      birthday = DateTime.now();
      onInit = birthday;
      firstNameController = TextEditingController();
      lastNameController = TextEditingController();
      qualifications = [];
    }

    firstNameController.addListener(() {
      setState(() {});
    });

    lastNameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

  bool hasChanges() {
    if (widget.person == null) {
      if (onInit != birthday) return true;
      if (firstNameController.text.isNotEmpty) return true;
      if (lastNameController.text.isNotEmpty) return true;
      if (qualifications.isNotEmpty) return true;
      return false;
    }

    if (firstNameController.text != widget.person!.firstName) return true;
    if (lastNameController.text != widget.person!.lastName) return true;
    if (birthday != widget.person!.birthday) return true;
    if (qualifications.length != widget.person!.qualifications.length) return true;
    for (var qualification in qualifications) {
      String qualificationString = qualification.toString();
      bool found = false;
      for (var existing in widget.person!.qualifications) {
        if (qualificationString == existing.toString()) {
          found = true;
          break;
        }
      }
      if (!found) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasChanges(),
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (!hasChanges()) {
          Navigator.of(context).pop();
          return;
        }
        discardDialog(context);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: true,
          title: Text(widget.person == null ? 'Person erstellen' : 'Person bearbeiten'),
          actions: const [
            // TODO
          ],
        ),
        floatingActionButton: !hasChanges()
            ? null
            : FloatingActionButton(
                heroTag: 'personSave',
                onPressed: () {
                  // TODO
                },
                child: const Icon(Icons.save_outlined),
              ),
        body: ListView(
          padding: const EdgeInsets.all(8),
          children: [
          ],
        ),
      ),
    );
  }
}
