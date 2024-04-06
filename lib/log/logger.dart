import 'package:flutter/foundation.dart';
import 'package:flutter_colored_print/flutter_colored_print.dart';

abstract class Logger {
  static void logSegmentedBuffers(dynamic text, {LogType type = LogType.primary, LogColor color = LogColor.white}) {
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
    logSegmentedBuffers(text, type: LogType.primary, color: LogColor.black);
  }

  static void error(dynamic text) {
    if (!kDebugMode) return;
    logSegmentedBuffers(text, type: LogType.error, color: LogColor.red);
  }

  static void ok(dynamic text) {
    if (!kDebugMode) return;
    logSegmentedBuffers(text, type: LogType.success, color: LogColor.green);
  }

  static void warn(dynamic text) {
    if (!kDebugMode) return;
    logSegmentedBuffers(text, type: LogType.warning, color: LogColor.yellow);
  }

  static void info(dynamic text) {
    if (!kDebugMode) return;
    logSegmentedBuffers(text, type: LogType.info, color: LogColor.blue);
  }

  static void fcm(dynamic text) {
    if (!kDebugMode) return;
    logSegmentedBuffers(text, type: LogType.info, color: LogColor.magenta);
  }

  static void net(dynamic text) {
    if (!kDebugMode) return;
    logSegmentedBuffers(text, type: LogType.info, color: LogColor.cyan);
  }

  static void updateStream(dynamic text) {
    if (!kDebugMode) return;
    logSegmentedBuffers(text, type: LogType.info, color: LogColor.grey);
  }

  static void white(dynamic text) {
    if (!kDebugMode) return;
    logSegmentedBuffers(text, type: LogType.primary, color: LogColor.white);
  }
}
