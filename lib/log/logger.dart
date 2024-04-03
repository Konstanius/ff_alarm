import 'package:flutter/foundation.dart';
import 'package:flutter_colored_print/flutter_colored_print.dart';

abstract class Logger {
  static void logLineByLine(dynamic text, {LogType type = LogType.primary, LogColor color = LogColor.white}) {
    if (!kDebugMode) return;
    String toLog = text.toString();

    while (toLog.length > 512) {
      log(toLog.substring(0, 512), type: type, color: color);
      toLog = toLog.substring(512);
    }
    log(toLog, type: type, color: color);
  }
  
  static void black(dynamic text) {
    if (!kDebugMode) return;
    logLineByLine(text, type: LogType.primary, color: LogColor.black);
  }

  // error
  static void error(dynamic text) {
    if (!kDebugMode) return;
    logLineByLine(text, type: LogType.error, color: LogColor.red);
  }

  // success
  static void ok(dynamic text) {
    if (!kDebugMode) return;
    logLineByLine(text, type: LogType.success, color: LogColor.green);
  }

  // warn
  static void warn(dynamic text) {
    if (!kDebugMode) return;
    logLineByLine(text, type: LogType.warning, color: LogColor.yellow);
  }

  // info
  static void info(dynamic text) {
    if (!kDebugMode) return;
    logLineByLine(text, type: LogType.info, color: LogColor.blue);
  }

  // fcm
  static void fcm(dynamic text) {
    if (!kDebugMode) return;
    logLineByLine(text, type: LogType.info, color: LogColor.magenta);
  }

  // networking
  static void net(dynamic text) {
    if (!kDebugMode) return;
    logLineByLine(text, type: LogType.info, color: LogColor.cyan);
  }

  // Update stream
  static void updateStream(dynamic text) {
    if (!kDebugMode) return;
    logLineByLine(text, type: LogType.info, color: LogColor.grey);
  }

  static void white(dynamic text) {
    if (!kDebugMode) return;
    logLineByLine(text, type: LogType.primary, color: LogColor.white);
  }
}
