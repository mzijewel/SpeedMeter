import 'dart:math';

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
  List<LatLng> _rawPoints = [];
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _rawPoints = widget.trip.waypoints
        .map((w) => LatLng(w['lat']!, w['lng']!))
        .toList();
    _routePoints = _rawPoints.length > 2 ? _rdp(_rawPoints, 8.0) : _rawPoints;

    if (_rawPoints.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitBounds(_routePoints.isNotEmpty ? _routePoints : _rawPoints);
      });
    }
  }

  // Ramer-Douglas-Peucker simplification with epsilon in metres.
  List<LatLng> _rdp(List<LatLng> points, double epsilon) {
    if (points.length < 3) return points;
    double maxDist = 0;
    int maxIdx = 0;
    for (int i = 1; i < points.length - 1; i++) {
      final d = _perpDist(points[i], points.first, points.last);
      if (d > maxDist) {
        maxDist = d;
        maxIdx = i;
      }
    }
    if (maxDist > epsilon) {
      final left = _rdp(points.sublist(0, maxIdx + 1), epsilon);
      final right = _rdp(points.sublist(maxIdx), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    }
    return [points.first, points.last];
  }

  // Perpendicular distance from point p to segment (a, b) in metres.
  double _perpDist(LatLng p, LatLng a, LatLng b) {
    const metersPerDeg = 111320.0;
    final cosLat = cos(p.latitude * pi / 180.0);
    final px = (p.longitude - a.longitude) * metersPerDeg * cosLat;
    final py = (p.latitude - a.latitude) * metersPerDeg;
    final dx = (b.longitude - a.longitude) * metersPerDeg * cosLat;
    final dy = (b.latitude - a.latitude) * metersPerDeg;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return sqrt(px * px + py * py);
    final t = ((px * dx + py * dy) / len2).clamp(0.0, 1.0);
    return sqrt(pow(px - t * dx, 2) + pow(py - t * dy, 2));
  }

  void _fitBounds(List<LatLng> points) {
    if (points.length < 2) return;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points.skip(1)) {
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
      body: _rawPoints.isEmpty ? _buildNoRoute() : _buildMap(),
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
    final displayPoints = _routePoints.isNotEmpty ? _routePoints : _rawPoints;
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _rawPoints[_rawPoints.length ~/ 2],
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.speed_meter',
        ),
        if (displayPoints.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: displayPoints,
                color: const Color(0xFF00E676),
                strokeWidth: 4,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: _rawPoints.first,
              child: const Icon(
                Icons.trip_origin,
                color: Color(0xFF00E676),
                size: 22,
              ),
            ),
            if (_rawPoints.length > 1)
              Marker(
                point: _rawPoints.last,
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
