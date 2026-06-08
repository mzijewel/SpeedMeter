import 'dart:async';

import 'package:flutter/material.dart';

import '../models/trip_data.dart';
import '../services/location_service.dart';
import '../widgets/permission_prompt.dart';
import '../widgets/speedometer_gauge.dart';
import '../widgets/stats_row.dart';

class SpeedScreen extends StatefulWidget {
  const SpeedScreen({super.key});

  @override
  State<SpeedScreen> createState() => _SpeedScreenState();
}

class _SpeedScreenState extends State<SpeedScreen> {
  late final LocationService _locationService;
  StreamSubscription<TripData>? _subscription;
  TripData _tripData = TripData.initial();

  @override
  void initState() {
    super.initState();
    _locationService = LocationService();
    _subscription = _locationService.tripStream.listen((data) {
      if (mounted) setState(() => _tripData = data);
    });
    _locationService.initialize();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _locationService.dispose();
    super.dispose();
  }

  Color _accuracyColor(double accuracy) {
    if (accuracy < 10) return const Color(0xFF00E676);
    if (accuracy < 30) return const Color(0xFFFFEB3B);
    return const Color(0xFFD50000);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: switch (_tripData.status) {
          TripStatus.initializing => _buildLoading(),
          TripStatus.permissionDenied ||
          TripStatus.permissionPermanentlyDenied =>
            PermissionPrompt(
              status: _tripData.status,
              onRetry: () => _locationService.retryPermission(),
            ),
          _ => _buildTrackingScreen(),
        },
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFF00E676)),
          SizedBox(height: 20),
          Text(
            'Initializing GPS...',
            style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingScreen() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SpeedometerGauge(speedKmh: _tripData.currentSpeedKmh),
          ),
        ),
        _buildSpeedLabel(),
        const SizedBox(height: 20),
        StatsRow(
          maxSpeedKmh: _tripData.maxSpeedKmh,
          avgSpeedKmh: _tripData.avgSpeedKmh,
          distanceMeters: _tripData.distanceMeters,
        ),
        const SizedBox(height: 16),
        _buildResetButton(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHeader() {
    final bool noFix = _tripData.status == TripStatus.noGpsFix;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'SPEED METER',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: noFix
                      ? const Color(0xFFD50000)
                      : _accuracyColor(_tripData.gpsAccuracy),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                noFix
                    ? 'Searching...'
                    : '±${_tripData.gpsAccuracy.toStringAsFixed(0)}m',
                style: const TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedLabel() {
    return Column(
      children: [
        Text(
          _tripData.currentSpeedKmh.toStringAsFixed(0),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 80,
            fontWeight: FontWeight.w200,
            letterSpacing: -2,
            height: 1.0,
          ),
        ),
        const Text(
          'km/h',
          style: TextStyle(
            color: Color(0xFF9E9E9E),
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildResetButton() {
    return TextButton(
      onPressed: _locationService.resetTrip,
      child: const Text(
        'RESET TRIP',
        style: TextStyle(
          color: Color(0xFF9E9E9E),
          fontSize: 13,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
