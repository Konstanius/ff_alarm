import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.initialPosition, required this.positionsNotifier, required this.controller});

  final LatLng initialPosition;
  final ValueNotifier<List<MapPos>> positionsNotifier;
  final MapController controller;

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
        initialZoom: 15.5,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          keepBuffer: 30,
        ),
        ValueListenableBuilder(
          valueListenable: widget.positionsNotifier,
          builder: (BuildContext context, List<MapPos> positions, Widget? child) {
            return MarkerLayer(
              markers: [
                for (var position in positions)
                  Marker(
                    width: 80.0,
                    alignment: Alignment.topCenter,
                    point: position.position,
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
      ],
    );
  }
}

class MapPos {
  String id;
  LatLng position;
  String name;
  Widget widget;

  MapPos({required this.id, required this.position, required this.name, required this.widget});
}
