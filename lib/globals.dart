import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:app_group_directory/app_group_directory.dart';
import 'package:background_fetch/background_fetch.dart' as bf;
import 'package:ff_alarm/data/database.dart';
import 'package:ff_alarm/data/models/alarm.dart';
import 'package:ff_alarm/data/models/person.dart';
import 'package:ff_alarm/data/prefs.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:ff_alarm/main.dart';
import 'package:ff_alarm/server/request.dart';
import 'package:ff_alarm/ui/home.dart';
import 'package:ff_alarm/ui/screens/alarm_info.dart';
import 'package:ff_alarm/ui/screens/login_screen.dart';
import 'package:ff_alarm/ui/screens/person_screen.dart';
import 'package:ff_alarm/ui/screens/station_screen.dart';
import 'package:ff_alarm/ui/screens/unit_screen.dart';
import 'package:ff_alarm/ui/settings/alarm_settings.dart';
import 'package:ff_alarm/ui/settings/lifecycle.dart';
import 'package:ff_alarm/ui/settings/notifications.dart';
import 'package:ff_alarm/ui/utils/updater.dart';
import 'package:ff_alarm/ui/utils/versioning.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

abstract class Globals {
  static const MethodChannel channel = MethodChannel('app.feuerwehr.jena.de/methods');

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // ignore: close_sinks
  static StreamController<UpdateInfo> updateStream = StreamController<UpdateInfo>.broadcast();

  static BuildContext? get context => navigatorKey.currentContext;

  static late final String filesPath;
  static late final String cachePath;
  static late final Prefs prefs;
  static late final AppDatabase db;

  static Future<void> initialize(bool geo) async {
    if (initialized) {
      await initializeTemporary(geo);
      return;
    }
    initialized = true;
    if (!Platform.isIOS) {
      filesPath = (await getApplicationSupportDirectory()).path;
    } else {
      // Since we are trying to share assets with the app extension, we need to use the group directory
      filesPath = (await AppGroupDirectory.getAppGroupDirectory('group.de.jena.feuerwehr.app.ffAlarm'))!.path;
    }
    cachePath = (await getTemporaryDirectory()).path;

    prefs = Prefs(identifier: 'main');

    db = await $FloorAppDatabase.databaseBuilder('database.db').buildBetterPath();

    await Versioning.upgradeDatabase();

    await initializeTemporary(geo);
  }

  static Future<void> initGeoLocator() async {
    try {
      // check if permission is granted, else throw
      if (!await Geolocator.isLocationServiceEnabled()) {
        lastPosition = null;
        lastPositionTime = null;
        Globals.positionSubscription?.cancel();
        Globals.positionSubscription = null;
        throw 'Location service is disabled';
      }

      var status = await Geolocator.checkPermission();
      if (status == LocationPermission.denied) {
        lastPosition = null;
        lastPositionTime = null;
        Globals.positionSubscription?.cancel();
        Globals.positionSubscription = null;
        throw 'Location permission is denied';
      }

      // read last location from file
      try {
        String path = '$filesPath/last_location.txt';
        File file = File(path);
        if (file.existsSync()) {
          List<String> parts = file.readAsStringSync().split(',');
          if (parts.length == 3) {
            double lat = double.tryParse(parts[0]) ?? 0;
            double lon = double.tryParse(parts[1]) ?? 0;
            int time = int.tryParse(parts[2]) ?? 0;
            lastPosition = Position(
              latitude: lat,
              longitude: lon,
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
              timestamp: DateTime.now(),
              floor: 0,
              isMocked: false,
            );
            lastPositionTime = DateTime.fromMillisecondsSinceEpoch(time);
          }
        }
      } catch (e, s) {
        Logger.warn('Failed to read last location: $e\n$s');
      }

      var permissionAlways = await Permission.locationAlways.isGranted;
      if (permissionAlways && !Globals.isService) {
        // check if any geofence is active
        var all = SettingsNotificationData.getAll();
        bool geofenceActive = false;
        for (var data in all.values) {
          if (data.geofencing.isNotEmpty && data.manualOverride == 1 && data.enabledMode == 3) {
            geofenceActive = true;
            break;
          }
        }

        if (geofenceActive) {
          if (Platform.isAndroid) {
            var service = FlutterBackgroundService();

            if (!await service.isRunning()) {
              await service.configure(
                androidConfiguration: AndroidConfiguration(
                  isForegroundMode: true,
                  autoStart: true,
                  autoStartOnBoot: true,
                  foregroundServiceNotificationId: 112233,
                  initialNotificationTitle: "FF Alarm Geofence",
                  initialNotificationContent: "FF Alarm Geofencing ist aktiv im Hintergrund.",
                  onStart: onServiceStartAndroid,
                  notificationChannelId: 'geofence',
                ),
              );

              await service.startService();
            }
          } else if (Platform.isIOS) {
            bg.BackgroundGeolocation.onLocation((bg.Location location) async {
              await initialize(false);
              String iosPath = (await AppGroupDirectory.getAppGroupDirectory('group.de.jena.feuerwehr.app.ffAlarm'))!.path;
              File file = File("$iosPath/last_location.txt");
              var now = DateTime.now();
              file.writeAsStringSync("${location.coords.latitude},${location.coords.longitude},${now.millisecondsSinceEpoch}");

              var all = SettingsNotificationData.getAll();
              if (all.isNotEmpty) {
                bool geofenceActive = false;
                for (var data in all.values) {
                  if (data.geofencing.isNotEmpty && data.manualOverride == 1 && data.enabledMode == 3) {
                    geofenceActive = true;
                    break;
                  }
                }

                if (!geofenceActive) {
                  return;
                }
              } else {
                return;
              }

              try {
                var servers = Globals.registeredServers;

                var futures = <Future>[];
                for (var server in servers) {
                  futures.add(
                    Request('personSetLocation', {'a': location.coords.latitude, 'o': location.coords.longitude, 't': now.millisecondsSinceEpoch}, server).emit(true),
                  );
                }

                await Future.wait(futures);
              } catch (e, s) {
                Logger.warn('Failed to send location: $e\n$s');
              }
            });
            bg.BackgroundGeolocation.onHeartbeat((callback) async {
              String iosPath = (await AppGroupDirectory.getAppGroupDirectory('group.de.jena.feuerwehr.app.ffAlarm'))!.path;
              File file = File("$iosPath/location_log.txt");

              // write current date as iso string, then event, then location
              file.writeAsStringSync('${DateTime.now().toIso8601String()}: heartbeat\n', mode: FileMode.append);
            });

            bg.BackgroundGeolocation.ready(iosBackgroundLocationConfig).then((bg.State state) {
              if (!state.enabled) {
                bg.BackgroundGeolocation.start();
              }
            });

            bf.BackgroundFetch.configure(
              iosBackgroundFetchConfig,
              (String taskId) async {
                print('STARTED BACKGROUND FETCH');
                try {
                  await initialize(false);

                  String path = '${Globals.filesPath}/last_location.txt';
                  File file = File(path);
                  if (!file.existsSync()) {
                    throw 'File does not exist';
                  }
                  String content = file.readAsStringSync();
                  List<String> parts = content.split(',');
                  if (parts.length != 3) {
                    throw 'Invalid content';
                  }

                  double lat = double.tryParse(parts[0]) ?? 0;
                  double lon = double.tryParse(parts[1]) ?? 0;

                  try {
                    var servers = Globals.registeredServers;

                    var futures = <Future>[];
                    for (var server in servers) {
                      futures.add(
                        Request('personSetLocation', {'a': lat, 'o': lon, 't': DateTime.now().millisecondsSinceEpoch}, server).emit(true),
                      );
                    }

                    await Future.wait(futures);
                  } catch (e, s) {
                    Logger.warn('Failed to send location: $e\n$s');
                  }
                  print('FINISHED BACKGROUND FETCH');
                } catch (e, s) {
                  Logger.error('Failed to run background fetch: $e\n$s');
                  print('FAILED TO RUN BACKGROUND FETCH');
                }

                bf.BackgroundFetch.finish(taskId);
              },
              (String taskId) async {
                bf.BackgroundFetch.finish(taskId);
              },
            ).then((int status) {
              if (status == bf.BackgroundFetch.STATUS_AVAILABLE) {
                bf.BackgroundFetch.scheduleTask(
                  bf.TaskConfig(
                    taskId: 'com.jena.feuerwehr.ffAlarm.backgroundFetch',
                    delay: 15,
                    periodic: true,
                    forceAlarmManager: true,
                    stopOnTerminate: false,
                    enableHeadless: true,
                    startOnBoot: true,
                    requiredNetworkType: bf.NetworkType.ANY,
                    requiresBatteryNotLow: false,
                    requiresCharging: false,
                    requiresStorageNotLow: false,
                    requiresDeviceIdle: false,
                    requiresNetworkConnectivity: true,
                    type: bf.TaskType.DEFAULT,
                  ),
                ).then((bool success) {
                  if (!success) {
                    Logger.error('Failed to schedule background fetch');

                    bf.BackgroundFetch.start();
                  }
                });
              }
            });
          }
        } else {
          if (Platform.isAndroid) {
            // none, stops itself
          } else if (Platform.isIOS) {
            bg.BackgroundGeolocation.ready(iosBackgroundLocationConfig).then((bg.State state) {
              if (state.enabled) {
                bg.BackgroundGeolocation.stop();
              }
            });

            bf.BackgroundFetch.stop();
          }
        }
      }

      if (positionSubscription != null) {
        positionSubscription!.cancel();
        positionSubscription = null;
      }

      positionSubscription = Geolocator.getPositionStream().listen((Position position) {
        if (lastPositionTime != null && DateTime.now().difference(lastPositionTime!) < const Duration(seconds: 3)) return;
        lastPosition = position;
        lastPositionTime = DateTime.now();
        UpdateInfo(UpdateType.ui, {"2"});
      });

      // get initial position
      Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 5)).then((Position? position) {
        lastPosition = position;
        lastPositionTime = DateTime.now();
        UpdateInfo(UpdateType.ui, {"2"});
      }).catchError((e, s) {
        Logger.warn('Failed to get initial position: $e\n$s');
      });
    } catch (e, s) {
      if (e is! String) {
        Logger.warn('Failed to initialize geolocator: $e\n$s');
      }
    }
  }

  static bg.Config get iosBackgroundLocationConfig => bg.Config(
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        distanceFilter: 50.0,
        stopTimeout: 5,
        debug: false,
        logLevel: bg.Config.LOG_LEVEL_OFF,
        disableElasticity: false,
        disableStopDetection: true,
        disableMotionActivityUpdates: true,
        disableLocationAuthorizationAlert: true,
        preventSuspend: true,
        startOnBoot: true,
        stopOnTerminate: false,
        allowIdenticalLocations: true,
        heartbeatInterval: 120,
        pausesLocationUpdatesAutomatically: false,
      );

  static bf.BackgroundFetchConfig iosBackgroundFetchConfig = bf.BackgroundFetchConfig(
    minimumFetchInterval: 15,
    stopOnTerminate: false,
    startOnBoot: true,
    enableHeadless: true,
    requiresBatteryNotLow: false,
    requiresCharging: false,
    requiresStorageNotLow: false,
    requiresDeviceIdle: false,
    requiredNetworkType: bf.NetworkType.ANY,
  );

  static Future<void> initializeTemporary(bool geo) async {
    if (geo) await initGeoLocator();

    String registeredUsers = prefs.getString('registered_users') ?? '[]';
    List<String> users;
    try {
      users = jsonDecode(registeredUsers).cast<String>();
    } catch (e) {
      users = [];
    }

    Set<String> toRemove = {};
    if (users.isNotEmpty) {
      for (var user in users) {
        Person? person = await db.personDao.getById(user);
        if (person != null) {
          localPersons[user] = person;
        } else {
          Logger.error('Person "$user" not found in database');
          toRemove.add(user);
        }
      }
    }

    if (toRemove.isNotEmpty) {
      for (var user in toRemove) {
        await logout(user.split(' ')[0]);
      }
    }

    if (localPersons.isEmpty) {
      while (true) {
        try {
          Globals.router.go('/login');
          break;
        } catch (_) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }
    }
  }

  static bool initialized = false;
  static bool isService = false;
  static bool appStarted = false;
  static bool fastStartBypass = false;
  static bool foreground = false;
  static ({String server, int receivedTime})? fcmTest;

  static List<String> get registeredServers {
    String registeredUsers = Globals.prefs.getString('registered_users') ?? '[]';
    List<String> users;
    try {
      users = jsonDecode(registeredUsers).cast<String>();
    } catch (e) {
      users = [];
    }

    List<String> servers = [];
    for (String user in users) {
      String server = user.split(' ')[0];
      if (!servers.contains(server)) servers.add(server);
    }

    return servers;
  }

  static Map<String, Person> localPersons = {};

  static String? localPersonForServer(String server) {
    for (var person in localPersons.values) {
      if (person.server == server) {
        return person.id;
      }
    }
    return null;
  }

  static Position? lastPosition;
  static DateTime? lastPositionTime;

  static StreamSubscription<Position>? positionSubscription;

  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) => const HomeScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'alarm',
            builder: (BuildContext context, GoRouterState state) {
              final Alarm alarm = state.extra! as Alarm;
              return AlarmPage(alarm: alarm);
            },
          ),
          GoRoute(
            path: 'lifecycle',
            builder: (BuildContext context, GoRouterState state) => const LifeCycleSettings(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (BuildContext context, GoRouterState state) => const NotificationSettings(),
          ),
          GoRoute(
            path: 'alarmsettings',
            builder: (BuildContext context, GoRouterState state) {
              final String stationId = state.extra! as String;
              return SettingsAlarmInformationPage(stationId: stationId);
            },
          ),
          GoRoute(
            path: 'login',
            onExit: (BuildContext context) {
              return Globals.localPersons.isNotEmpty;
            },
            builder: (BuildContext context, GoRouterState state) => const LoginScreen(),
          ),
          GoRoute(
            path: 'station',
            builder: (BuildContext context, GoRouterState state) {
              final String stationId = state.extra! as String;
              return StationPage(stationId: stationId);
            },
          ),
          GoRoute(
            path: 'unit',
            builder: (BuildContext context, GoRouterState state) {
              final String unitId = state.extra! as String;
              return UnitPage(unitId: unitId);
            },
          ),
          GoRoute(
            path: 'person',
            builder: (BuildContext context, GoRouterState state) {
              final String personId = state.extra! as String;
              return PersonPage(personId: personId);
            },
          ),
        ],
      ),
    ],
  );
}

/// Refreshes every 5 minutes, if position changed by 50 meters or more
/// Serverside treats a position as unreliable after 10 minutes
Future<({LatLng? pos, int? lastTime})> backgroundGPSSync(LatLng? previousPos, int? lastTime) async {
  try {
    if (Globals.lastPositionTime?.isBefore(DateTime.now().subtract(const Duration(minutes: 1))) ?? true) {
      var location = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 30));
      Globals.lastPosition = location;
      Globals.lastPositionTime = DateTime.now();
    }

    if (Globals.lastPosition == null) return (pos: previousPos, lastTime: lastTime);

    String path = '${Globals.filesPath}/last_location.txt';
    File file = File(path);
    file.writeAsStringSync("${Globals.lastPosition!.latitude},${Globals.lastPosition!.longitude},${Globals.lastPositionTime!.millisecondsSinceEpoch}");

    int delay = DateTime.now().millisecondsSinceEpoch - (lastTime ?? 0);
    if (previousPos != null && delay < 600000) {
      double distance = Geolocator.distanceBetween(previousPos.latitude, previousPos.longitude, Globals.lastPosition!.latitude, Globals.lastPosition!.longitude);
      if (distance < 50) return (pos: previousPos, lastTime: lastTime);
    }

    try {
      var servers = Globals.registeredServers;

      var futures = <Future>[];
      for (var server in servers) {
        futures.add(
          Request('personSetLocation', {'a': Globals.lastPosition!.latitude, 'o': Globals.lastPosition!.longitude, 't': Globals.lastPositionTime!.millisecondsSinceEpoch}, server).emit(true),
        );
      }

      await Future.wait(futures);
    } catch (e, s) {
      Logger.warn('Failed to send location: $e\n$s');
    }

    return (pos: LatLng(Globals.lastPosition!.latitude, Globals.lastPosition!.longitude), lastTime: Globals.lastPositionTime!.millisecondsSinceEpoch);
  } catch (e, s) {
    Logger.error('Failed to get location: $e\n$s');
    return (pos: previousPos, lastTime: lastTime);
  }
}

@pragma('vm:entry-point')
void onServiceStartAndroid(ServiceInstance instance) async {
  Globals.isService = true;
  DartPluginRegistrant.ensureInitialized();

  bool locationGranted = await Permission.locationAlways.isGranted;
  if (!locationGranted) {
    await instance.stopSelf();
    return;
  }
  await Globals.initialize(true);

  var all = SettingsNotificationData.getAll();
  if (all.isNotEmpty) {
    bool geofenceActive = false;
    for (var data in all.values) {
      if (data.geofencing.isNotEmpty && data.manualOverride == 1 && data.enabledMode == 3) {
        geofenceActive = true;
        break;
      }
    }

    if (!geofenceActive) {
      await instance.stopSelf();
      return;
    }
  } else {
    await instance.stopSelf();
    return;
  }

  LatLng? previousPos;
  int? previousTime;
  while (true) {
    var result = await backgroundGPSSync(previousPos, previousTime);
    previousPos = result.pos;
    previousTime = result.lastTime;

    int delay = 60;
    while (delay > 0) {
      await Future.delayed(const Duration(seconds: 1));

      try {
        File file = File("${Globals.filesPath}/notification_settings.json");
        bool exists = file.existsSync();
        if (exists && DateTime.now().difference(file.lastModifiedSync()).inSeconds < 60) {
          var all = SettingsNotificationData.getAll();
          if (all.isNotEmpty) {
            bool geofenceActive = false;
            for (var data in all.values) {
              if (data.geofencing.isNotEmpty && data.manualOverride == 1 && data.enabledMode == 3) {
                geofenceActive = true;
                break;
              }
            }

            if (!geofenceActive) {
              await instance.stopSelf();
              return;
            }
          } else {
            await instance.stopSelf();
            return;
          }
        } else if (!exists) {
          await instance.stopSelf();
          return;
        }

        delay--;
      } catch (e, s) {
        Logger.error('Failed to check notification settings: $e\n$s');
      }
    }
  }
}
