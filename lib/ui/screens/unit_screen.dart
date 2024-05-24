import 'package:ff_alarm/data/interfaces/unit_interface.dart';
import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/data/models/unit.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/ui/screens/person_manage.dart';
import 'package:ff_alarm/ui/screens/station_screen.dart';
import 'package:ff_alarm/ui/screens/person_picker.dart';
import 'package:ff_alarm/ui/utils/dialogs.dart';
import 'package:ff_alarm/ui/utils/format.dart';
import 'package:ff_alarm/ui/utils/large_card.dart';
import 'package:ff_alarm/ui/utils/toasts.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';

import '../utils/no_data.dart';

class UnitPage extends StatefulWidget {
  const UnitPage({super.key, required this.unit});

  final Unit unit;

  @override
  State<UnitPage> createState() => _UnitPageState();
}

class _UnitPageState extends State<UnitPage> with Updates {
  bool loading = true;
  Unit? unit;
  Station? station;
  List<Person>? persons;

  ScrollController scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUnit();

    setupListener({UpdateType.station, UpdateType.unit, UpdateType.person});
  }

  void _loadUnit() async {
    try {
      unit = await Globals.db.unitDao.getById(widget.unit.id);
      unit ??= widget.unit;

      station = await Globals.db.stationDao.getById(unit!.stationProperId);
      if (station == null) {
        throw Exception('Station not found');
      }

      persons = await Globals.db.personDao.getWhereIn(station!.personProperIds);
      persons!.removeWhere((element) => !element.allowedUnitProperIds.contains(unit!.id));
      persons!.sort((a, b) {
        if (station!.adminPersonProperIds.contains(a.id)) return -1;
        if (station!.adminPersonProperIds.contains(b.id)) return 1;
        return a.fullName.compareTo(b.fullName);
      });
    } catch (e, s) {
      Logger.error('Failed to load unit: $e\n$s');
      unit = null;
      station = null;
      persons = null;
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox();

    if (station == null || unit == null) {
      return const NoDataWidget(text: 'Einheit konnte nicht geladen werden', enableAppBar: true, appBarText: 'Einheit');
    }

    String? localPersonForServer = Globals.localPersonForServer(station!.server);
    bool isAdmin = localPersonForServer != null && station!.adminPersonProperIds.contains(localPersonForServer);

    var now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text('Einheit'),
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
                            Globals.context!.loaderOverlay.show();
                            Set<String> allowedPersonIds = station!.personProperIds.toSet();
                            for (var person in persons!) {
                              allowedPersonIds.remove(person.id);
                            }

                            var stationMembers = await Person.getByIds(allowedPersonIds);
                            Globals.context!.loaderOverlay.hide();

                            Person? result = await Navigator.of(Globals.context!).push(MaterialPageRoute(builder: (context) => PersonPicker(persons: stationMembers)));
                            if (result == null) return;

                            Globals.context!.loaderOverlay.show();
                            try {
                              await UnitInterface.addPerson(server: unit!.server, unitId: unit!.idNumber, personId: result.idNumber);
                              Navigator.of(Globals.context!).pop();
                              await Future.delayed(const Duration(milliseconds: 20));
                              successToast('Die Person wurde der Einheit erfolgreich hinzugefügt.');
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
                                Flexible(child: Text('Person auswählen')),
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
            LargeCard(firstRow: unit!.unitDescription, secondRow: unit!.callSign, sourceString: unit!.server),
            const SizedBox(height: 8),
            Card(
              elevation: 4,
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Icon(unit!.statusEnum.icon, color: unit!.statusEnum.color),
                    const SizedBox(width: 8),
                    Text("${unit!.statusEnum.description} (Status ${unit!.status})"),
                  ],
                ),
              ),
            ),
            Card(
              elevation: 4,
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: InkWell(
                onTap: () {
                  Globals.router.push('/station', extra: station!);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Icon(Icons.local_fire_department_outlined),
                      const SizedBox(width: 8),
                      Flexible(child: Text('Wache: ${station!.descriptiveName}')),
                    ],
                  ),
                ),
              ),
            ),
            Card(
              elevation: 4,
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Icon(Icons.groups_outlined),
                    const SizedBox(width: 8),
                    Text('Zugelassene Personen: ${persons!.length}'),
                  ],
                ),
              ),
            ),
            Card(
              elevation: 4,
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Icon(Icons.fire_truck_outlined),
                    const SizedBox(width: 8),
                    Text('Mannschaft: ${unit!.positionsDescription}'),
                  ],
                ),
              ),
            ),
            ...StationPageState.getPersonsDisplay(
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
                      Card(
                        elevation: 4,
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        child: InkWell(
                          onTap: () async {
                            bool confirm = await generalDialog(
                              color: Colors.red,
                              title: 'Person entfernen',
                              content: Text('Möchtest du ${person.fullName} wirklich von der Einheit entfernen?'),
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
                              await UnitInterface.removePerson(
                                server: station!.server,
                                unitId: unit!.idNumber,
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
                                Flexible(child: Text('Von Einheit entfernen')),
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
    if (info.type == UpdateType.station && info.ids.contains(unit!.stationProperId)) {
      station = await Globals.db.stationDao.getById(unit!.stationProperId);
      persons = await Globals.db.personDao.getWhereIn(station!.personProperIds);
      persons!.removeWhere((element) => !element.allowedUnitProperIds.contains(unit!.id));
      persons!.sort((a, b) {
        if (station!.adminPersonProperIds.contains(a.id)) return -1;
        if (station!.adminPersonProperIds.contains(b.id)) return 1;
        return a.fullName.compareTo(b.fullName);
      });
    }

    if (info.type == UpdateType.unit && info.ids.contains(widget.unit.id)) {
      unit = await Globals.db.unitDao.getById(widget.unit.id);
    }

    if (info.type == UpdateType.person && station != null) {
      persons = await Globals.db.personDao.getWhereIn(station!.personProperIds);
      persons!.removeWhere((element) => !element.allowedUnitProperIds.contains(unit!.id));
      persons!.sort((a, b) {
        if (station!.adminPersonProperIds.contains(a.id)) return -1;
        if (station!.adminPersonProperIds.contains(b.id)) return 1;
        return a.fullName.compareTo(b.fullName);
      });
    }

    if (mounted) setState(() {});
  }
}
