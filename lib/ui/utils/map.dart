import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPage extends StatefulWidget {
  const MapPage({
    super.key,
    required this.initialPosition,
    required this.positionsNotifier,
    required this.controller,
    this.initialZoom = 15.5,
    this.onTap,
  });

  final LatLng initialPosition;
  final ValueNotifier<List<MapPos>> positionsNotifier;
  final MapController controller;
  final double initialZoom;
  final void Function(TapPosition, LatLng)? onTap;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: widget.controller,
      options: MapOptions(
        initialCenter: widget.initialPosition,
        initialZoom: widget.initialZoom,
        onTap: widget.onTap,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          keepBuffer: 2,
          panBuffer: 1,
        ),
        ValueListenableBuilder(
          valueListenable: widget.positionsNotifier,
          builder: (BuildContext context, List<MapPos> positions, Widget? child) {
            return MarkerLayer(
              markers: [
                for (var position in positions.where((element) => element.radius == null))
                  Marker(
                    width: 80.0,
                    height: 100,
                    alignment: Alignment.center,
                    point: position.position,
                    rotate: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        position.widget,
                        Text(position.name, style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        ValueListenableBuilder(
          valueListenable: widget.positionsNotifier,
          builder: (BuildContext context, List<MapPos> positions, Widget? child) {
            return CircleLayer(
              circles: [
                for (var position in positions.where((element) => element.radius != null))
                  CircleMarker(
                    point: position.position,
                    radius: position.radius!.toDouble(),
                    color: Colors.blue.withOpacity(0.3),
                    borderColor: Colors.blue,
                    borderStrokeWidth: 2,
                    useRadiusInMeter: true,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class MapPos {
  String id;
  LatLng position;
  String name;
  Widget widget;
  int? radius;

  MapPos({
    required this.id,
    required this.position,
    required this.name,
    required this.widget,
    this.radius,
  });
}

extension SmoothMapController on MapController {
  Future<void> smoothMove(LatLng position, double zoom) async {
    double startX = camera.center.latitude;
    double startY = camera.center.longitude;
    double startZoom = zoom;

    double dx = position.latitude - startX;
    double dy = position.longitude - startY;
    double dz = zoom - startZoom;

    const minStepSize = 0.001;
    const maxSteps = 100;

    int steps = (dx.abs() / minStepSize).ceil();
    steps = steps > maxSteps ? maxSteps : steps;

    double stepX = dx / steps;
    double stepY = dy / steps;
    double stepZ = dz / steps;

    for (int i = 1; i <= steps; i++) {
      try {
        await Future.delayed(const Duration(milliseconds: 17));
        move(LatLng(startX + stepX * i, startY + stepY * i), startZoom + stepZ * i);
      } catch (_) {
        return;
      }
    }

    move(position, zoom);
  }
}
