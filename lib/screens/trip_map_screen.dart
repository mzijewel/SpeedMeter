import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/trip.dart';

class TripMapScreen extends StatefulWidget {
  final Trip trip;

  const TripMapScreen({super.key, required this.trip});

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  final MapController _mapController = MapController();
  late final List<LatLng> _points;

  @override
  void initState() {
    super.initState();
    _points = widget.trip.waypoints
        .map((w) => LatLng(w['lat']!, w['lng']!))
        .toList();

    if (_points.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
    }
  }

  void _fitBounds() {
    if (_points.length < 2) return;
    double minLat = _points.first.latitude;
    double maxLat = _points.first.latitude;
    double minLng = _points.first.longitude;
    double maxLng = _points.first.longitude;
    for (final p in _points.skip(1)) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat, minLng),
          LatLng(maxLat, maxLng),
        ),
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        foregroundColor: Colors.white,
        title: const Text(
          'TRIP ROUTE',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),
      ),
      body: _points.isEmpty ? _buildNoRoute() : _buildMap(),
    );
  }

  Widget _buildNoRoute() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 64, color: Color(0xFF2D2D44)),
          SizedBox(height: 16),
          Text(
            'No route data available',
            style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Route tracking is only available for new trips',
            style: TextStyle(color: Color(0xFF555566), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _points[_points.length ~/ 2],
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.speed_meter',
        ),
        if (_points.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _points,
                color: const Color(0xFF00E676),
                strokeWidth: 4,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: _points.first,
              child: const Icon(
                Icons.trip_origin,
                color: Color(0xFF00E676),
                size: 22,
              ),
            ),
            if (_points.length > 1)
              Marker(
                point: _points.last,
                child: const Icon(
                  Icons.location_pin,
                  color: Color(0xFFD50000),
                  size: 30,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
