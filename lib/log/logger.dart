import 'package:flutter/foundation.dart';
import 'package:flutter_colored_print/flutter_colored_print.dart';

abstract class Logger {
  static void black(dynamic text) {
    if (!kDebugMode) return;
    log(text, type: LogType.info, color: LogColor.black);
  }

  static void red(dynamic text) {
    if (!kDebugMode) return;
    log(text, type: LogType.error, color: LogColor.red);
  }

  static void green(dynamic text) {
    if (!kDebugMode) return;
    log(text, type: LogType.success, color: LogColor.green);
  }

  static void yellow(dynamic text) {
    if (!kDebugMode) return;
    log(text, type: LogType.warning, color: LogColor.yellow);
  }

  static void blue(dynamic text) {
    if (!kDebugMode) return;
    log(text, type: LogType.info, color: LogColor.blue);
  }

  static void magenta(dynamic text) {
    if (!kDebugMode) return;
    log(text, type: LogType.info, color: LogColor.magenta);
  }

  static void cyan(dynamic text) {
    if (!kDebugMode) return;
    log(text, type: LogType.info, color: LogColor.cyan);
  }

  static void grey(dynamic text) {
    if (!kDebugMode) return;
    log(text, type: LogType.info, color: LogColor.grey);
  }

  static void white(dynamic text) {
    if (!kDebugMode) return;
    log(text, type: LogType.primary, color: LogColor.white);
  }
}
