import 'package:ff_alarm/data/interfaces/person_interface.dart';
import 'package:ff_alarm/data/interfaces/station_interface.dart';
import 'package:ff_alarm/data/interfaces/unit_interface.dart';
import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/data/models/unit.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/ui/home/settings_screen.dart';
import 'package:ff_alarm/ui/screens/person_manage.dart';
import 'package:ff_alarm/ui/screens/person_picker.dart';
import 'package:ff_alarm/ui/utils/dialogs.dart';
import 'package:ff_alarm/ui/utils/format.dart';
import 'package:ff_alarm/ui/utils/large_card.dart';
import 'package:ff_alarm/ui/utils/no_data.dart';
import 'package:ff_alarm/ui/utils/toasts.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:map_launcher/map_launcher.dart';

class StationPage extends StatefulWidget {
  const StationPage({super.key, required this.station});

  final Station station;

  @override
  State<StationPage> createState() => StationPageState();
}

class StationPageState extends State<StationPage> with Updates {
  bool loading = true;
  Station? station;
  List<Person>? persons;
  List<Unit>? units;

  ScrollController scrollController = ScrollController();

  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController birthdayController = TextEditingController(text: Formats.date(DateTime.now()));

  @override
  void dispose() {
    scrollController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    birthdayController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadStation();

    station = widget.station;

    setupListener({UpdateType.station, UpdateType.person, UpdateType.unit});
  }

  void _loadStation() async {
    try {
      station = await Globals.db.stationDao.getById(widget.station.id);

      persons = await Globals.db.personDao.getWhereIn(station!.personProperIds);
      persons!.sort((a, b) {
        if (station!.adminPersonProperIds.contains(a.id)) return -1;
        if (station!.adminPersonProperIds.contains(b.id)) return 1;
        return a.fullName.compareTo(b.fullName);
      });

      units = await Globals.db.unitDao.getWhereStationIn(station!.idNumber, station!.server);
      units!.sort((a, b) => a.callSign.compareTo(b.callSign));

      String? localPersonForServer = Globals.localPersonForServer(station!.server);
      bool admin = localPersonForServer != null && station!.adminPersonProperIds.contains(localPersonForServer);
      if (admin) {
        try {
          units = await UnitInterface.fetchForStationAsAdmin(station!.server, station!.idNumber);
          units!.sort((a, b) => a.callSign.compareTo(b.callSign));
        } catch (e, s) {
          Logger.error('Failed to fetch units for station as admin: $e\n$s');
        }
      }
    } catch (e) {
      station = null;
      persons = null;
      units = null;
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox();

    if (station == null || persons == null || units == null) {
      return const NoDataWidget(text: 'Wache konnte nicht geladen werden', enableAppBar: true, appBarText: 'Wache');
    }

    String? localPersonForServer = Globals.localPersonForServer(station!.server);
    bool isAdmin = localPersonForServer != null && station!.adminPersonProperIds.contains(localPersonForServer);

    var now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text('Wache'),
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              onPressed: () {
                generalDialog(
                  color: Colors.blue,
                  title: 'Person hinzufügen',
                  content: Column(
                    children: [
                      Card(
                        elevation: 4,
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        child: InkWell(
                          onTap: () async {
                            bool? result = await generalDialog(
                              color: Colors.blue,
                              title: 'Person suchen',
                              content: Column(
                                children: [
                                  TextField(
                                    controller: firstNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Vorname',
                                      border: OutlineInputBorder(),
                                    ),
                                    textCapitalization: TextCapitalization.words,
                                  ),
                                  const SizedBox(height: 24),
                                  TextField(
                                    controller: lastNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nachname',
                                      border: OutlineInputBorder(),
                                    ),
                                    textCapitalization: TextCapitalization.words,
                                  ),
                                  const SizedBox(height: 24),
                                  TextField(
                                    controller: birthdayController,
                                    readOnly: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Geburtstag',
                                      border: OutlineInputBorder(),
                                    ),
                                    onTap: () async {
                                      DateTime? date = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime(1900),
                                        lastDate: DateTime.now(),
                                        initialDatePickerMode: DatePickerMode.year,
                                        initialEntryMode: DatePickerEntryMode.input,
                                      );
                                      if (date != null) {
                                        birthdayController.text = Formats.date(date);
                                      }
                                    },
                                  ),
                                ],
                              ),
                              actions: [
                                DialogActionButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(false);
                                  },
                                  text: 'Abbrechen',
                                ),
                                DialogActionButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(true);
                                  },
                                  text: 'Suchen',
                                ),
                              ],
                            );
                            String firstName = firstNameController.text.trim();
                            String lastName = lastNameController.text.trim();
                            DateTime birthday = Formats.parseDate(birthdayController.text);
                            if (result != true) return;

                            try {
                              Globals.context!.loaderOverlay.show();

                              var persons = await PersonInterface.search(firstName: firstName, lastName: lastName, birthday: birthday, server: station!.server);
                              if (persons.isEmpty) {
                                errorToast('Keine Person gefunden');
                                return;
                              }
                              Globals.context!.loaderOverlay.hide();

                              Person? picked = await Navigator.of(Globals.context!).push(MaterialPageRoute(builder: (context) => PersonPicker(persons: persons)));
                              if (picked == null) return;

                              Globals.context!.loaderOverlay.show();

                              await StationInterface.addPerson(
                                server: station!.server,
                                stationId: station!.idNumber,
                                personId: picked.idNumber,
                              );

                              Navigator.of(Globals.context!).pop();

                              await Future.delayed(const Duration(milliseconds: 20));

                              successToast('Die Person wurde der Wache erfolgreich hinzugefügt');

                              firstNameController.clear();
                              lastNameController.clear();
                              birthdayController.text = Formats.date(DateTime.now());
                            } catch (e, s) {
                              exceptionToast(e, s);
                            } finally {
                              Globals.context!.loaderOverlay.hide();
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Icon(Icons.person_search_outlined),
                                SizedBox(width: 8),
                                Flexible(child: Text('Person suchen')),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Card(
                        elevation: 4,
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(MaterialPageRoute(builder: (context) => PersonManageScreen(station: station!)));
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Icon(Icons.person_add_outlined),
                                SizedBox(width: 8),
                                Flexible(child: Text('Person erstellen')),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    DialogActionButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      text: 'Schließen',
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            LargeCard(firstRow: station!.name, secondRow: station!.descriptiveNameShort, sourceString: station!.server),
            const SizedBox(height: 8),
            Card(
              elevation: 4,
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: InkWell(
                onTap: () async {
                  if (station!.position == null) {
                    errorToast('Keine Koordinaten vorhanden');
                    return;
                  }

                  var maps = await MapLauncher.installedMaps;
                  if (maps.isNotEmpty) {
                    await MapLauncher.showMarker(
                      mapType: MapType.google,
                      title: station!.descriptiveName,
                      coords: Coords(station!.position!.latitude, station!.position!.longitude),
                    );
                  } else {
                    errorToast('Keine Karten-App gefunden');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined),
                      const SizedBox(width: 8),
                      Flexible(child: Text(station!.address)),
                    ],
                  ),
                ),
              ),
            ),
            Card(
              elevation: 4,
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: InkWell(
                onTap: () async {
                  if (station!.position == null) {
                    errorToast('Keine Koordinaten vorhanden');
                    return;
                  }

                  var maps = await MapLauncher.installedMaps;
                  if (maps.isNotEmpty) {
                    await MapLauncher.showMarker(
                      mapType: MapType.google,
                      title: station!.descriptiveName,
                      coords: Coords(station!.position!.latitude, station!.position!.longitude),
                    );
                  } else {
                    errorToast('Keine Karten-App gefunden');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      if (station!.position != null) const Icon(Icons.gps_fixed_outlined) else const Icon(Icons.gps_off_outlined),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(() {
                          if (station!.position == null) return 'Keine Koordinaten vorhanden';
                          var pos = station!.position!;
                          return '${pos.latitude.toStringAsFixed(5)} ° N,   ${pos.longitude.toStringAsFixed(5)} ° E';
                        }()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SettingsDivider(text: 'Einheiten'),
            for (int i = 0; i < units!.length; i++) ...[
              () {
                var unit = units![i];
                return Card(
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: ListTile(
                    onTap: () {
                      Globals.router.push('/unit', extra: unit);
                    },
                    title: Text(
                      unit.callSign,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: kDefaultFontSize * 1.3,
                      ),
                    ),
                    subtitle: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${unit.unitDescription}   ( ${unit.positionsDescription} )"),
                        () {
                          int count = 0;
                          for (var person in persons!) {
                            if (person.allowedUnitProperIds.contains(unit.id)) {
                              count++;
                            }
                          }

                          return Row(
                            children: [
                              const Text(
                                'Zugelassene Personen:  ',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                count.toString(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          );
                        }(),
                      ],
                    ),
                    trailing: () {
                      var status = UnitStatus.fromInt(unit.status);
                      return Text(
                        status.value.toString(),
                        style: TextStyle(
                          color: status.color,
                          fontWeight: FontWeight.bold,
                          fontSize: kDefaultFontSize * 1.6,
                        ),
                      );
                    }(),
                  ),
                );
              }(),
            ],
            ...getPersonsDisplay(
              station!,
              context,
              persons!,
              now,
              (person) {
                if (!isAdmin) {
                  Globals.router.push('/person', extra: person);
                  return;
                }

                generalDialog(
                  color: Colors.blue,
                  title: person.fullName,
                  content: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        child: Row(
                          children: [
                            Text(
                              'Geboren: ${Formats.date(person.birthday)}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      Card(
                        elevation: 4,
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            Globals.router.push('/person', extra: person);
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outlined),
                                SizedBox(width: 8),
                                Flexible(child: Text('Details anzeigen')),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Card(
                        elevation: 4,
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(MaterialPageRoute(builder: (context) => PersonManageScreen(station: station!, person: person)));
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Icon(Icons.edit_outlined),
                                SizedBox(width: 8),
                                Flexible(child: Text('Bearbeiten')),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (person.id != localPersonForServer)
                        Card(
                          elevation: 4,
                          clipBehavior: Clip.antiAliasWithSaveLayer,
                          child: InkWell(
                            onTap: () async {
                              bool confirm = await generalDialog(
                                color: Colors.red,
                                title: 'Person entfernen',
                                content: Text('Möchtest du ${person.fullName} wirklich von der Wache entfernen?'),
                                actions: [
                                  DialogActionButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(true);
                                    },
                                    text: 'Ja',
                                  ),
                                  DialogActionButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(false);
                                    },
                                    text: 'Nein',
                                  ),
                                ],
                              );
                              if (confirm != true) return;

                              Globals.context!.loaderOverlay.show();
                              try {
                                await StationInterface.removePerson(
                                  server: station!.server,
                                  stationId: station!.idNumber,
                                  personId: person.idNumber,
                                );
                                Navigator.of(Globals.context!).pop();
                              } catch (e, s) {
                                exceptionToast(e, s);
                              } finally {
                                Globals.context!.loaderOverlay.hide();
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Icon(Icons.person_remove_outlined),
                                  SizedBox(width: 8),
                                  Flexible(child: Text('Aus Wache entfernen')),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (person.id != localPersonForServer)
                        Card(
                          elevation: 4,
                          clipBehavior: Clip.antiAliasWithSaveLayer,
                          child: InkWell(
                            onTap: () async {
                              bool toAdmin = !station!.adminPersonProperIds.contains(person.id);
                              bool? confirm = await generalDialog(
                                color: Colors.red,
                                title: toAdmin ? 'Person zum Admin machen' : 'Admin entfernen',
                                content: toAdmin
                                    ? Text('Möchtest du ${person.fullName} wirklich zum Wachen-Admin machen?')
                                    : Text('Möchtest du ${person.fullName} wirklich den Admin-Status der Wache entziehen?'),
                                actions: [
                                  DialogActionButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(true);
                                    },
                                    text: 'Ja',
                                  ),
                                  DialogActionButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(false);
                                    },
                                    text: 'Nein',
                                  ),
                                ],
                              );
                              if (confirm != true) return;

                              Globals.context!.loaderOverlay.show();
                              try {
                                await StationInterface.setAdmin(
                                  toAdmin: toAdmin,
                                  server: station!.server,
                                  stationId: station!.idNumber,
                                  personId: person.idNumber,
                                );
                                Navigator.of(Globals.context!).pop();
                              } catch (e, s) {
                                exceptionToast(e, s);
                              } finally {
                                Globals.context!.loaderOverlay.hide();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  if (station!.adminPersonProperIds.contains(person.id)) const Icon(Icons.remove_moderator_outlined) else const Icon(Icons.admin_panel_settings_outlined),
                                  const SizedBox(width: 8),
                                  if (station!.adminPersonProperIds.contains(person.id)) const Flexible(child: Text('Admin entfernen')) else const Flexible(child: Text('Zum Admin machen')),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  actions: [
                    DialogActionButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      text: 'Schließen',
                    ),
                  ],
                );
              },
              scrollController,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void onUpdate(UpdateInfo info) async {
    if (info.type == UpdateType.station && info.ids.contains(widget.station.id)) {
      List<String> previousIds = station!.personProperIds;
      station = await Globals.db.stationDao.getById(widget.station.id);
      if (station!.personProperIds.length != previousIds.length) {
        persons = await Globals.db.personDao.getWhereIn(station!.personProperIds);
        persons!.sort((a, b) {
          if (station!.adminPersonProperIds.contains(a.id)) return -1;
          if (station!.adminPersonProperIds.contains(b.id)) return 1;
          return a.fullName.compareTo(b.fullName);
        });
      }
    }

    if (info.type == UpdateType.person) {
      persons = await Globals.db.personDao.getWhereIn(station!.personProperIds);
      persons!.sort((a, b) {
        if (station!.adminPersonProperIds.contains(a.id)) return -1;
        if (station!.adminPersonProperIds.contains(b.id)) return 1;
        return a.fullName.compareTo(b.fullName);
      });
    }

    if (info.type == UpdateType.unit) {
      units = await Globals.db.unitDao.getWhereStationIn(station!.idNumber, station!.server);
      units!.sort((a, b) => a.callSign.compareTo(b.callSign));

      String? localPersonForServer = Globals.localPersonForServer(station!.server);
      bool admin = localPersonForServer != null && station!.adminPersonProperIds.contains(localPersonForServer);
      if (admin) {
        try {
          units = await UnitInterface.fetchForStationAsAdmin(station!.server, station!.idNumber);
          units!.sort((a, b) => a.callSign.compareTo(b.callSign));
        } catch (e, s) {
          Logger.error('Failed to fetch units for station as admin: $e\n$s');
        }
      }
    }
    if (mounted) setState(() {});
  }

  static List<Widget> getPersonsDisplay(
    Station station,
    BuildContext context,
    List<Person> persons,
    DateTime now,
    Function(Person person) onTap,
    ScrollController scrollController,
  ) {
    return [
      const SettingsDivider(text: 'Personen'),
      () {
        Map<String, int> qualificationsCount = {};
        for (var person in persons) {
          for (var qualification in person.qualifications) {
            if (qualification.start == null) continue;
            if (qualification.end != null) {
              if (qualification.end!.isBefore(now)) continue;
            }

            if (!qualificationsCount.containsKey(qualification.type)) {
              qualificationsCount[qualification.type] = 0;
            }
            qualificationsCount[qualification.type] = qualificationsCount[qualification.type]! + 1;
          }
        }

        List<({String type, int count})> qualificationsCountList = [];
        for (var entry in qualificationsCount.entries) {
          qualificationsCountList.add((type: entry.key, count: entry.value));
        }
        qualificationsCountList.sort((a, b) => a.type.startsWith('_') ? a.type.substring(1).compareTo(b.type.startsWith('_') ? b.type.substring(1) : b.type) : a.type.compareTo(b.type));

        return Card(
          clipBehavior: Clip.antiAliasWithSaveLayer,
          elevation: 2,
          margin: const EdgeInsets.only(left: 2, right: 2, bottom: 8, top: 4),
          child: Column(
            children: [
              const SizedBox(height: 4),
              Text(
                'Qualifikationsauflistung',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              RawScrollbar(
                controller: scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 5.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              child: Row(
                                children: [
                                  Text(' ', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            for (var entry in qualificationsCountList) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                child: Row(
                                  children: [
                                    Text(
                                      () {
                                        if (entry.type.startsWith('_')) {
                                          return entry.type.substring(1);
                                        }
                                        return entry.type;
                                      }(),
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              child: Row(
                                children: [
                                  Text(
                                    'Bereit',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (var entry in qualificationsCountList) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                child: Row(
                                  children: [
                                    Text(
                                      entry.count.toString(),
                                      style: const TextStyle(color: Colors.green),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(width: 4),
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              child: Row(
                                children: [
                                  Text(
                                    "< ${DateFormat('dd.MM.').format(now.add(const Duration(days: 120)))}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (var entry in qualificationsCountList) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                child: Row(
                                  children: [
                                    Text(
                                      () {
                                        int count = 0;
                                        for (var person in persons) {
                                          for (var qualification in person.visibleQualificationsAt(now)) {
                                            if (qualification.type == entry.type && qualification.end != null && qualification.end!.difference(now).inDays < 120 && qualification.end!.isAfter(now)) {
                                              count++;
                                            }
                                          }
                                        }
                                        return count.toString();
                                      }(),
                                      style: const TextStyle(color: Colors.amber),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(width: 4),
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              child: Row(
                                children: [
                                  Text(
                                    "< ${DateFormat('dd.MM.').format(now.add(const Duration(days: 30)))}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (var entry in qualificationsCountList) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                child: Row(
                                  children: [
                                    Text(
                                      () {
                                        int count = 0;
                                        for (var person in persons) {
                                          for (var qualification in person.visibleQualificationsAt(now)) {
                                            if (qualification.type == entry.type && qualification.end != null && qualification.end!.difference(now).inDays < 30 && qualification.end!.isAfter(now)) {
                                              count++;
                                            }
                                          }
                                        }
                                        return count.toString();
                                      }(),
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(width: 4),
                        Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              child: Row(
                                children: [
                                  Text(
                                    'Abgel.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (var entry in qualificationsCountList) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                child: Row(
                                  children: [
                                    Text(
                                      () {
                                        int count = 0;
                                        for (var person in persons) {
                                          for (var qualification in person.visibleQualificationsAt(now)) {
                                            if (qualification.type == entry.type && qualification.end != null && qualification.end!.isAfter(now)) {
                                              count++;
                                            }
                                          }
                                        }
                                        return count.toString();
                                      }(),
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                // total persons and admins count
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        child: Row(
                          children: [
                            Text(
                              'Gesamt: ',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        child: Row(
                          children: [
                            Text(
                              persons.length.toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        child: Row(
                          children: [
                            Text(
                              'Administratoren: ',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        child: Row(
                          children: [
                            Text(
                              station.adminPersonProperIds.length.toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      }(),
      for (int i = 0; i < persons.length; i++) ...[
        () {
          var person = persons[i];
          return personDisplayCard(
            person: person,
            onTap: onTap,
            now: now,
            trailing: (person) {
              if (station.adminPersonProperIds.contains(person.id)) {
                return const Icon(Icons.admin_panel_settings_outlined);
              }
              return const SizedBox();
            },
          );
        }(),
      ],
    ];
  }

  static Card personDisplayCard({
    required Person person,
    required void Function(Person person) onTap,
    required DateTime now,
    Widget Function(Person person)? trailing,
  }) {
    return Card(
      clipBehavior: Clip.antiAliasWithSaveLayer,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: ListTile(
        onTap: () => onTap(person),
        title: Text(
          person.fullName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: kDefaultFontSize * 1.3,
          ),
        ),
        subtitle: RichText(
          text: TextSpan(
            children: () {
              var children = <InlineSpan>[];

              for (var qualification in person.qualifications) {
                Color color = Colors.green;
                if (qualification.end != null) {
                  if (qualification.end!.isBefore(now)) {
                    color = Colors.grey;
                  } else if (qualification.end!.difference(now).inDays < 30) {
                    color = Colors.red;
                  } else if (qualification.end!.difference(now).inDays < 120) {
                    color = Colors.orange;
                  }
                }

                children.add(
                  TextSpan(
                    text: () {
                      if (qualification.type.startsWith('_')) {
                        return qualification.type.substring(1);
                      }
                      return qualification.type;
                    }(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
                children.add(const TextSpan(text: ',  '));
              }

              if (children.isNotEmpty) children.removeLast();

              return children;
            }(),
          ),
        ),
        trailing: trailing != null ? trailing(person) : null,
      ),
    );
  }
}
