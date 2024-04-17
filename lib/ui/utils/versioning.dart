import 'package:ff_alarm/globals.dart';
import 'package:ff_alarm/log/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

abstract class Versioning {
  static const List<int> versions = [
    3,
    4,
  ];

  static final List<Function> upgrades = [
    () async {},
    () async {
      /// Added column "birthday" of type int to table "Person"
      await Globals.db.database.execute('ALTER TABLE [Person] ADD COLUMN birthday INTEGER NOT NULL DEFAULT 0;');
    },
  ];

  static Future<void> upgradeDatabase() async {
    var packageInfo = await PackageInfo.fromPlatform();
    int currentVersion = int.tryParse(packageInfo.buildNumber) ?? 0;
    int lastVersion = Globals.prefs.getInt('db_version') ?? currentVersion;

    Logger.ok('Current database version: $lastVersion');

    for (int i = 0; i < versions.length; i++) {
      if (lastVersion < versions[i] && currentVersion >= versions[i]) {
        await upgrades[i]();
        Globals.prefs.setInt('db_version', versions[i]);

        Logger.ok('Upgraded database to version ${versions[i]}');
      }
    }

    Globals.prefs.setInt('db_version', currentVersion);
  }
}
