import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/data/models/unit.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/ui/screens/station_screen.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';

class UnitPage extends StatefulWidget {
  const UnitPage({super.key, required this.unitId});

  final String unitId;

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
      unit = await Globals.db.unitDao.getById(widget.unitId);
      if (unit == null) {
        throw Exception('Unit not found');
      }

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
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: true,
          title: const Text('Einheit'),
        ),
        body: const Center(child: Text("Einheit konnte nicht geladen werden")),
      );
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
                // TODO
              },
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Card(
                margin: const EdgeInsets.all(0),
                elevation: 100,
                clipBehavior: Clip.antiAliasWithSaveLayer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.width / 2,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                unit!.unitDescription,
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width / (unit!.unitDescription.length > 20 ? 20 : unit!.unitDescription.length),
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                unit!.callSign,
                                style: const TextStyle(fontSize: kDefaultFontSize * 1.2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Quelle: ${() {
                    var uri = Uri.tryParse('http${unit!.server}');
                    if (uri == null) return 'http${unit!.server}';
                    return uri.host;
                  }()}',
                  style: const TextStyle(fontSize: kDefaultFontSize * 0.7),
                ),
              ],
            ),
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
                  Globals.router.go('/station', extra: unit!.stationProperId);
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
                  Globals.router.go('/person', extra: person.id);
                  return;
                }
                // TODO
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
    }

    if (info.type == UpdateType.unit && info.ids.contains(widget.unitId)) {
      unit = await Globals.db.unitDao.getById(widget.unitId);
    }

    if (info.type == UpdateType.person && station != null && station!.personProperIds.any((element) => info.ids.contains(element))) {
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
