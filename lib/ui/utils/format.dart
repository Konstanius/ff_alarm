import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

abstract class Formats {
  static String distanceBetween(Position a, Position b) {
    double distance = Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
    if (distance < 1000) {
      return "${distance.toStringAsFixed(0)} m";
    } else {
      return "${(distance / 1000).toStringAsFixed(2)} km";
    }
  }

  static Color invertColor(Color color) {
    return Color.fromARGB(255, 255 - color.red, 255 - color.green, 255 - color.blue);
  }

  static Color getReadableColor(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  static Color getContrastColor(Color color, [int maxContrast = 192]) {
    const minContrast = 128;
    double y = 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue;
    double oy = 255 - y;
    double dy = oy - y;
    if (dy.abs() > maxContrast) {
      dy = dy.sign * maxContrast;
      oy = y + dy;
    } else if (dy.abs() < minContrast) {
      dy = dy.sign * minContrast;
      oy = y + dy;
    }
    return Color.fromARGB(255, oy.toInt(), oy.toInt(), oy.toInt());
  }
}
