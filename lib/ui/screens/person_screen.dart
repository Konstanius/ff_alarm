import 'package:barcode/barcode.dart';
import 'package:ff_alarm/data/interfaces/person_interface.dart';
import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/data/models/station.dart';
import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/ui/home/settings_screen.dart';
import 'package:ff_alarm/ui/utils/format.dart';
import 'package:ff_alarm/ui/utils/large_card.dart';
import 'package:ff_alarm/ui/utils/no_data.dart';
import 'package:ff_alarm/ui/utils/toasts.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:share_plus/share_plus.dart';

class PersonPage extends StatefulWidget {
  const PersonPage({super.key, required this.person, this.registrationKey});

  final Person person;
  final String? registrationKey;

  @override
  State<PersonPage> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonPage> with Updates {
  final dm = Barcode.aztec(minECCPercent: 30);

  DateTime entry = DateTime.now();

  bool loading = true;
  List<Station>? stations;
  Person? person;

  String? registrationKey;
  String? registrationQrData;

  @override
  void initState() {
    super.initState();
    person = widget.person;

    registrationKey = widget.registrationKey;
    if (registrationKey != null) {}

    loadData();
    setupListener({UpdateType.station, UpdateType.person});
  }

  void generateQrData() {
    if (registrationKey == null) return;
    registrationQrData = dm.toSvg(registrationKey!);
    setState(() {});
  }

  @override
  void onUpdate(UpdateInfo info) async {
    if (info.type == UpdateType.person && info.ids.contains(person!.id)) {
      await loadData();
    } else if (info.type == UpdateType.station) {
      await loadData();
    }
  }

  Future<void> loadData() async {
    try {
      person = await Globals.db.personDao.getById(widget.person.id);
      if (person == null) {
        throw Exception('Person not found');
      }
      person!.qualifications.sort((a, b) => a.type.startsWith('_') ? a.type.substring(1).compareTo(b.type.startsWith('_') ? b.type.substring(1) : b.type) : a.type.compareTo(b.type));

      stations = await Station.getAll(filter: (station) => station.persons.contains(person!.idNumber));
    } catch (_) {
      person = null;
      stations = null;
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox();

    if (stations == null || person == null) {
      return const NoDataWidget(text: 'Person konnte nicht geladen werden', enableAppBar: true, appBarText: 'Person');
    }

    String? localPersonForServer = Globals.localPersonForServer(person!.server);
    bool isAdmin = localPersonForServer != null;
    if (isAdmin) {
      isAdmin = false;
      for (var station in stations!) {
        if (station.adminPersonProperIds.contains(localPersonForServer)) {
          isAdmin = true;
          break;
        }
      }
    }

    return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: true,
          title: const Text('Person'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            LargeCard(firstRow: person!.firstName, secondRow: person!.lastName, sourceString: person!.server),
            Card(
              elevation: 4,
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const Icon(Icons.cake_outlined),
                    const SizedBox(width: 8),
                    Text('Geboren: ${Formats.date(person!.birthday)}, Alter: ${person!.age}'),
                  ],
                ),
              ),
            ),
            if (isAdmin) ...[
              const SettingsDivider(text: 'Registrierungsschlüssel'),
              const SizedBox(height: 8),
              Card(
                elevation: 10,
                clipBehavior: Clip.antiAliasWithSaveLayer,
                color: Colors.white,
                child: InkWell(
                  onTap: registrationQrData != null
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => Scaffold(
                                backgroundColor: Colors.white,
                                appBar: AppBar(
                                  title: const Text('Registrierungsschlüssel'),
                                ),
                                body: SafeArea(
                                  child: Center(
                                    child: SvgPicture.string(
                                      registrationQrData!,
                                      height: MediaQuery.of(context).size.width * 0.95,
                                      width: MediaQuery.of(context).size.width * 0.95,
                                      fit: BoxFit.fitHeight,
                                      clipBehavior: Clip.antiAliasWithSaveLayer,
                                      alignment: Alignment.center,
                                      colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      : null,
                  child: Stack(
                    children: [
                      if (registrationQrData != null) ...[
                        SvgPicture.string(
                          registrationQrData!,
                          height: MediaQuery.of(context).size.width * 0.5,
                          width: MediaQuery.of(context).size.width * 0.5,
                          fit: BoxFit.contain,
                          clipBehavior: Clip.antiAliasWithSaveLayer,
                          alignment: Alignment.center,
                          colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                          placeholderBuilder: (_) => const Center(child: CircularProgressIndicator()),
                        ),
                        Positioned(
                          top: 5,
                          right: 5,
                          child: IconButton(
                            icon: Icon(Icons.share_outlined, color: Colors.black, size: MediaQuery.of(context).size.width * 0.08),
                            onPressed: () {
                              Share.share(registrationKey!);
                            },
                          ),
                        ),
                        const Positioned(
                          bottom: 5,
                          left: 5,
                          right: 5,
                          child: Center(
                            child: Text(
                              'Tippen zum Vergrößern',
                              style: TextStyle(color: Colors.black, fontSize: kDefaultFontSize * 0.7),
                            ),
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          height: MediaQuery.of(context).size.width * 0.5,
                          width: MediaQuery.of(context).size.width * 0.5,
                        ),
                        const Positioned.fill(
                          child: Center(
                            child: Text(
                              'Kein Registrierungsschlüssel vorhanden. Bitte generieren.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (registrationQrData != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Gültig bis: ${DateFormat('dd.MM.yyyy HH:mm').format(entry.add(const Duration(days: 1)))}',
                      style: const TextStyle(fontSize: kDefaultFontSize * 0.7),
                    ),
                  ],
                ),
              ElevatedButton(
                onPressed: () async {
                  Globals.context!.loaderOverlay.show();
                  try {
                    registrationKey = await PersonInterface.generateRegistrationKey(server: person!.server, personId: person!.idNumber);
                    entry = DateTime.now();
                    generateQrData();
                  } catch (e, s) {
                    exceptionToast(e, s);
                  } finally {
                    Globals.context!.loaderOverlay.hide();
                  }
                },
                child: const Text('Neuen Registrierungsschlüssel generieren'),
              ),
            ],
            const SettingsDivider(text: 'Qualifikationen'),
            for (var qualification in person!.qualifications)
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
                          enableFeedback: false,
                          onPressed: () {},
                        )
                      : IconButton(
                          icon: const Icon(Icons.visibility_outlined),
                          enableFeedback: false,
                          onPressed: () {},
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
                ),
              ),
          ],
        ));
  }
}
