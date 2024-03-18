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
}