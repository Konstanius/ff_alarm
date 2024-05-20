import 'package:ff_alarm/data/interfaces/person_interface.dart';
import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/ui/home/settings_screen.dart';
import 'package:ff_alarm/ui/utils/dialogs.dart';
import 'package:ff_alarm/ui/utils/format.dart';
import 'package:ff_alarm/ui/utils/large_card.dart';
import 'package:ff_alarm/ui/utils/toasts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loader_overlay/loader_overlay.dart';

class PersonManageScreen extends StatefulWidget {
  const PersonManageScreen({super.key, this.person, required this.station});

  final Person? person;
  final Station station;

  @override
  State<PersonManageScreen> createState() => _PersonManageScreenState();
}

class _PersonManageScreenState extends State<PersonManageScreen> {
  late DateTime birthday;
  late DateTime onInit;

  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController birthdayController;

  late List<Qualification> qualifications;

  @override
  void initState() {
    super.initState();
    if (widget.person != null) {
      birthday = widget.person!.birthday;

      firstNameController = TextEditingController(text: widget.person!.firstName);
      lastNameController = TextEditingController(text: widget.person!.lastName);
      birthdayController = TextEditingController(text: Formats.date(birthday));

      qualifications = [];
      for (var qualification in widget.person!.qualifications) {
        qualifications.add(Qualification.fromString(qualification.toString()));
      }

      qualifications.sort((a, b) => a.type.startsWith('_') ? a.type.substring(1).compareTo(b.type.startsWith('_') ? b.type.substring(1) : b.type) : a.type.compareTo(b.type));
    } else {
      birthday = DateTime.now();
      onInit = birthday;
      firstNameController = TextEditingController();
      lastNameController = TextEditingController();
      birthdayController = TextEditingController(text: Formats.date(birthday));
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
        ),
        floatingActionButton: !hasChanges()
            ? null
            : FloatingActionButton(
                backgroundColor: Colors.blue,
                heroTag: 'personSave',
                onPressed: () async {
                  if (firstNameController.text.isEmpty) {
                    errorToast('Vorname darf nicht leer sein');
                    return;
                  }
                  if (lastNameController.text.isEmpty) {
                    errorToast('Nachname darf nicht leer sein');
                    return;
                  }
                  if (qualifications.isEmpty) {
                    errorToast('Qualifikationen dürfen nicht leer sein');
                    return;
                  }

                  bool? confirm = await generalDialog(
                    color: Colors.blue,
                    title: widget.person == null ? 'Person erstellen' : 'Person bearbeiten',
                    content: widget.person == null ? const Text('Möchtest du diese Person wirklich erstellen?') : const Text('Möchtest du deine Änderungen an dieser Person wirklich speichern?'),
                    actions: [
                      DialogActionButton(
                        text: 'Abbrechen',
                        onPressed: () {
                          Navigator.of(Globals.context!).pop(false);
                        },
                      ),
                      DialogActionButton(
                        text: 'Speichern',
                        onPressed: () {
                          Navigator.of(Globals.context!).pop(true);
                        },
                      ),
                    ],
                  );
                  if (confirm != true) return;

                  Globals.context!.loaderOverlay.show();
                  try {
                    if (widget.person == null) {
                      var result = await PersonInterface.create(
                        server: widget.station.server,
                        stationId: widget.station.idNumber,
                        birthday: birthday,
                        firstName: firstNameController.text,
                        lastName: lastNameController.text,
                        qualifications: qualifications,
                      );
                      Navigator.of(Globals.context!).pop();
                      await Future.delayed(const Duration(milliseconds: 20));

                      Globals.router.go('/person', extra: {"person": result.person, "registrationKey": result.key});

                      successToast('Die Person wurde erstellt und der Wache hinzugefügt');
                    } else {
                      await PersonInterface.update(
                        server: widget.station.server,
                        stationId: widget.station.idNumber,
                        personId: widget.person!.idNumber,
                        birthday: birthday,
                        firstName: firstNameController.text,
                        lastName: lastNameController.text,
                        qualifications: qualifications,
                      );
                      Navigator.of(Globals.context!).pop();
                      await Future.delayed(const Duration(milliseconds: 20));

                      successToast('Die Änderungen an der Person wurden gespeichert');
                    }
                  } catch (e, s) {
                    exceptionToast(e, s);
                    return;
                  } finally {
                    Globals.context!.loaderOverlay.hide();
                  }
                },
                child: const Icon(Icons.save_outlined),
              ),
        body: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            LargeCard(
              firstRow: widget.station.name,
              secondRow: widget.station.descriptiveNameShort,
              thirdRow: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Änderungen an Personen sind für alle Wachen der Person auf diesem Server effektiv!',
                        style: TextStyle(fontSize: kDefaultFontSize, color: Colors.amber),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              sourceString: widget.station.server,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: firstNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Vorname',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: lastNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nachname',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: birthdayController,
              decoration: const InputDecoration(
                labelText: 'Geburtstag',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
              onTap: () async {
                DateTime? newBirthday = await showDatePicker(
                  context: context,
                  initialDate: birthday,
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  initialDatePickerMode: DatePickerMode.year,
                  initialEntryMode: DatePickerEntryMode.input,
                );
                if (newBirthday == null) return;
                setState(() {
                  birthday = newBirthday;
                  birthdayController.text = Formats.date(birthday);
                });
              },
            ),
            const SizedBox(height: 8),
            const SettingsDivider(text: 'Qualifikationen'),
            for (var qualification in qualifications)
              Card(
                elevation: 10,
                color: () {
                  if (qualification.isActive(DateTime.now())) {
                    return Colors.green.withOpacity(0.3);
                  } else {
                    return Colors.red.withOpacity(0.2);
                  }
                }(),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                  dense: true,
                  leading: qualification.hidden
                      ? IconButton(
                          icon: const Icon(Icons.visibility_off_outlined),
                          onPressed: () {
                            setState(() {
                              qualification.type = qualification.type.substring(1);
                            });
                          },
                        )
                      : IconButton(
                          icon: const Icon(Icons.visibility_outlined),
                          onPressed: () {
                            setState(() {
                              qualification.type = '_${qualification.type}';
                            });
                          },
                        ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          qualification.displayString,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (qualification.start != null) Text('Erhalt: ${Formats.date(qualification.start!)}') else const Text('Erhalt: Unbekannt'),
                      if (qualification.end != null) Text('Ablauf: ${Formats.date(qualification.end!)}') else const Text('Ablauf: Nie'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () {
                          qualificationDialog(qualification);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outlined),
                        onPressed: () {
                          setState(() {
                            qualifications.remove(qualification);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                Qualification qualification = Qualification('', null, null);

                await qualificationDialog(qualification);
                if (qualification.type.isEmpty) return;

                qualifications.add(qualification);
                setState(() {});
              },
              child: const Text('Qualifikation hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> qualificationDialog(Qualification qualification) async {
    TextEditingController typeController = TextEditingController(text: qualification.displayString);
    TextEditingController startController = TextEditingController(text: qualification.start == null ? 'Unbekannt' : Formats.date(qualification.start!));
    TextEditingController endController = TextEditingController(text: qualification.end == null ? 'Nie' : Formats.date(qualification.end!));
    bool hidden = qualification.hidden;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sbSetState) {
            return AlertDialog(
              title: const Text('Qualifikation'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: typeController,
                      decoration: const InputDecoration(
                        labelText: 'Typ',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'_'))],
                      maxLength: 50,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: startController,
                            decoration: const InputDecoration(
                              labelText: 'Erhalt',
                              border: OutlineInputBorder(),
                            ),
                            readOnly: true,
                            onTap: () async {
                              DateTime? newStart = await showDatePicker(
                                context: context,
                                initialDate: qualification.start ?? DateTime.now(),
                                firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 100)),
                              );
                              if (newStart == null) return;
                              startController.text = Formats.date(newStart);
                              sbSetState(() {});
                            },
                          ),
                        ),
                        if (startController.text != 'Unbekannt') const SizedBox(width: 8),
                        if (startController.text != 'Unbekannt')
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              startController.text = 'Unbekannt';
                              sbSetState(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: endController,
                            decoration: const InputDecoration(
                              labelText: 'Ablauf',
                              border: OutlineInputBorder(),
                            ),
                            readOnly: true,
                            onTap: () async {
                              DateTime? newEnd = await showDatePicker(
                                context: context,
                                initialDate: qualification.end ?? DateTime.now(),
                                firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 100)),
                              );
                              if (newEnd == null) return;
                              endController.text = Formats.date(newEnd);
                              sbSetState(() {});
                            },
                          ),
                        ),
                        if (endController.text != 'Nie') const SizedBox(width: 8),
                        if (endController.text != 'Nie')
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              endController.text = 'Nie';
                              sbSetState(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Versteckt'),
                        const Spacer(),
                        Switch(
                          value: hidden,
                          onChanged: (value) {
                            sbSetState(() {
                              hidden = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Abbrechen'),
                ),
                TextButton(
                  onPressed: () {
                    if (typeController.text.isEmpty) {
                      errorToast('Typ darf nicht leer sein');
                      return;
                    }

                    DateTime? start;
                    if (startController.text.isNotEmpty) {
                      try {
                        start = Formats.parseDate(startController.text);
                      } catch (_) {}
                    }

                    DateTime? end;
                    if (endController.text.isNotEmpty) {
                      try {
                        end = Formats.parseDate(endController.text);
                      } catch (_) {}
                    }

                    if (start != null && end != null && start.isAfter(end)) {
                      errorToast('Erhalt darf nicht nach Ablauf liegen');
                      return;
                    }

                    qualification.type = (hidden ? "_" : "") + typeController.text;
                    qualification.start = start;
                    qualification.end = end;
                    Navigator.of(context).pop();

                    setState(() {});
                  },
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
