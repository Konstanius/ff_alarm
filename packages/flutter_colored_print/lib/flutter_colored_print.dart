library flutter_colored_print;

import 'package:flutter/foundation.dart';

/// Logger supported types
enum LogType {
  error,
  warning,
  info,
  primary,
  success,
}

extension on LogType {
  String get title {
    switch (this) {
      case LogType.error:
        return "[Error]";
      case LogType.warning:
        return "[Warning]";
      case LogType.info:
        return "[Info]";
      case LogType.primary:
        return "[Primary]";
      case LogType.success:
        return "[Success]";
      default:
        return "[Log]";
    }
  }

  LogColor get color {
    switch (this) {
      case LogType.error:
        return LogColor.red;
      case LogType.warning:
        return LogColor.yellow;
      case LogType.info:
        return LogColor.cyan;
      case LogType.primary:
        return LogColor.blue;
      case LogType.success:
        return LogColor.green;
      default:
        return LogColor.black;
    }
  }
}

/// Logger supported colors
enum LogColor {
  black,
  magenta,
  cyan,
  yellow,
  green,
  red,
  white,
  blue,
  grey,
}

/// Color code on print
extension on LogColor {
  String get end {
    return "\x1B[0m";
  }

  String get start {
    switch (this) {
      case LogColor.white:
        return "\x1B[37m";
      case LogColor.cyan:
        return "\x1B[36m";
      case LogColor.magenta:
        return "\x1B[35m";
      case LogColor.blue:
        return "\x1B[34m";
      case LogColor.yellow:
        return "\x1B[33m";
      case LogColor.green:
        return "\x1B[32m";
      case LogColor.red:
        return "\x1B[31m";
      case LogColor.grey:
        return "\x1B[90m";
      case LogColor.black:
      default:
        return "\x1B[30m";
    }
  }
}

/// Logs a message to the console with the specified [LogType], [LogColor], and formatting options.
///
/// The [message] parameter is the message or data to be logged.
///
/// The [type] parameter is a [LogType] object representing the type of log message (e.g. "INFO", "DEBUG", "ERROR").
///
/// The [color] parameter is a [LogColor] object representing the color to use when formatting the log message.
///
/// The [allColored] parameter is a boolean value indicating whether to apply the [color] to the entire log message or just the output portion.
///
/// If the app is running in debug mode, the function formats and outputs the log message using the specified options.
///
/// Example usage:
/// ```
/// String message = "User 'johndoe' successfully logged in.";
/// LogType type = LogType.success;
/// LogColor color = LogColor.green;
/// log(message, type: type, color: color, allColored: true); // Logs "SUCCESS: User 'johndoe' successfully logged in." to the console in green.
/// ```
void log(Object? message, {LogType type = LogType.primary, LogColor color = LogColor.black, bool allColored = true}) {
  if (kDebugMode) {
    String output = handleMessage(message);
    String formatted = formatOutput(output, type, color, allColored);
    print(formatted);
  }
}

/// Logs an error message to the console with the specified formatting options.
///
/// The [message] parameter is the error message or data to be logged.
///
/// The [allColored] parameter is a boolean value indicating whether to apply the [LogColor] to the entire log message or just the output portion.
///
/// If the app is running in debug mode, the function formats and outputs the log message using the specified options.
///
/// Example usage:
/// ```
/// String errorMessage = "Error: Failed to load data.";
/// error(errorMessage, allColored: true); // Logs "ERROR: Failed to load data." to the console in red.
/// ```
void error(Object? message, {bool allColored = true}) {
  log(message, type: LogType.error, color: LogType.error.color, allColored: allColored);
}

/// Logs a warning message to the console with the specified formatting options.
///
/// The [message] parameter is the warning message or data to be logged.
///
/// The [allColored] parameter is a boolean value indicating whether to apply the [LogColor] to the entire log message or just the output portion.
///
/// If the app is running in debug mode, the function formats and outputs the log message using the specified options.
///
/// Example usage:
/// ```
/// String warningMessage = "Warning: User 'johndoe' has an expired subscription.";
/// warn(warningMessage, allColored: true); // Logs "WARNING: User 'johndoe' has an expired subscription." to the console in yellow.
/// ```
void warn(Object? message, {bool allColored = true}) {
  log(message, type: LogType.warning, color: LogType.error.color, allColored: allColored);
}

/// Logs an informational message to the console with the specified formatting options.
///
/// The [message] parameter is the informational message or data to be logged.
///
/// The [allColored] parameter is a boolean value indicating whether to apply the [LogColor] to the entire log message or just the output portion.
///
/// If the app is running in debug mode, the function formats and outputs the log message using the specified options.
///
/// Example usage:
/// ```
/// String infoMessage = "User 'johndoe' viewed their account settings.";
/// info(infoMessage, allColored: true); // Logs "INFO: User 'johndoe' viewed their account settings." to the console in cyan.
/// ```
void info(Object? message, {bool allColored = true}) {
  log(message, type: LogType.info, color: LogType.error.color, allColored: allColored);
}

/// Logs a message to the console with the primary log type and a magenta color.
///
/// The [message] parameter is the message or data to be logged.
///
/// The [allColored] parameter is a boolean value indicating whether to apply the color to the entire log message or just the output portion.
///
/// If the app is running in debug mode, the function formats and outputs the log message using the primary log type and magenta color.
///
/// Example usage:
/// ```
/// String message = "An error occurred while processing the user's request.";
/// primary(message, allColored: true); // Logs "[PRIMARY] An error occurred while processing the user's request." to the console in magenta.
/// ```
void primary(Object? message, {bool allColored = true}) {
  log(message, type: LogType.error, color: LogType.error.color, allColored: allColored);
}

/// Formats a log output string with a specified [LogType], [LogColor], and formatting options.
///
/// The [output] parameter is the message or data to be logged.
///
/// The [type] parameter is a [LogType] object representing the type of log message (e.g. "INFO", "DEBUG", "ERROR").
///
/// The [color] parameter is a [LogColor] object representing the color to use when formatting the log message.
///
/// The [allColored] parameter is a boolean value indicating whether to apply the [color] to the entire log message or just the output portion.
///
/// The function returns a formatted string with the log type and message content appropriately styled.
///
/// Example usage:
/// ```
/// String message = "User 'johndoe' successfully logged in.";
/// LogType type = LogType.info;
/// LogColor color = LogColor.green;
/// String formatted = formatOutput(message, type, color, true); // Returns "INFO: User 'johndoe' successfully logged in."
/// ```
String formatOutput(String output, LogType type, LogColor color, bool allColored) {
  String formattedTitle = "${type.color.start}${type.title}${type.color.end}";
  String formattedMessage = allColored ? "${color.start}$output${color.end}" : output;
  return "$formattedTitle $formattedMessage";
}

/// Converts an [Object] message to a [String] representation for logging purposes.
///
/// If the [message] parameter is `null`, returns the string "null object".
///
/// If the [message] parameter is a [String], returns the string itself.
///
/// If the [message] parameter is a [Map] or [List], returns its [String] representation.
///
/// For all other [Object] types, returns the result of calling the `toString()` method on the object.
///
/// Example usage:
/// ```
/// Object obj = {'name': 'John', 'age': 30};
/// String message = handleMessage(obj); // Returns "{name: John, age: 30}"
/// ```
String handleMessage(Object? message) {
  if (message == null) {
    return "null object";
  }

  if (message is String) {
    return message;
  }

  if (message is Map) {
    return message.toString();
  }

  if (message is List) {
    return message.toString();
  }

  return message.toString();
}
