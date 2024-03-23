import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';

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

  static Future<LatLng?> getCoordinates(String address) async {
    String escapedAddress = Uri.encodeComponent(address);
    String url = 'https://nominatim.openstreetmap.org/search?q=$escapedAddress&format=json';
    Dio dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)));
    Response response = await dio.get(url);
    if (response.statusCode == 200) {
      List<dynamic> data = response.data;
      if (data.isNotEmpty) {
        String lat = data[0]['lat'];
        String lon = data[0]['lon'];
        return LatLng(double.parse(lat), double.parse(lon));
      } else {
        return null;
      }
    }

    throw Exception('Failed to get coordinates');
  }

  static Future<String?> getAddress(LatLng position) async {
    String url = 'https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json';
    Dio dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)));
    Response response = await dio.get(url);
    if (response.statusCode == 200) {
      Map<String, dynamic> data = response.data;
      if (data.isNotEmpty) {
        return data['display_name'];
      } else {
        return null;
      }
    }

    throw Exception('Failed to get address');
  }

  static LatLng positionToLatLng(Position position) => LatLng(position.latitude, position.longitude);

  static Position latLngToPosition(LatLng latLng) => Position(
        latitude: latLng.latitude,
        longitude: latLng.longitude,
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

  static String dateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
