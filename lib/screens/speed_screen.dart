import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/trip_data.dart';
import '../services/location_service.dart';
import '../services/trip_storage_service.dart';
import '../widgets/permission_prompt.dart';
import '../widgets/speedometer_gauge.dart';
import '../widgets/stats_row.dart';
import 'trip_history_screen.dart';

class SpeedScreen extends StatefulWidget {
  const SpeedScreen({super.key});

  @override
  State<SpeedScreen> createState() => _SpeedScreenState();
}

class _SpeedScreenState extends State<SpeedScreen> {
  late final LocationService _locationService;
  final TripStorageService _storage = TripStorageService();
  StreamSubscription<TripData>? _subscription;
  TripData _tripData = TripData.initial();

  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

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
    _elapsedTimer?.cancel();
    _subscription?.cancel();
    _locationService.dispose();
    super.dispose();
  }

  void _onStartTrip() {
    _locationService.startTrip();
    setState(() => _elapsed = Duration.zero);
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _onStopTrip() async {
    _elapsedTimer?.cancel();
    final trip = _locationService.stopTrip();
    if (trip != null) {
      await _storage.saveTrip(trip);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Trip saved — ${_formatDuration(trip.duration)}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF1A1A2E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Color _accuracyColor(double accuracy) {
    if (accuracy < 10) return const Color(0xFF00E676);
    if (accuracy < 30) return const Color(0xFFFFEB3B);
    return const Color(0xFFD50000);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
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
          // GPS off is not a dead end: show the normal screen with the
          // start button disabled and a banner to enable GPS.
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

  bool get _gpsOff => _tripData.status == TripStatus.locationServiceDisabled;

  Widget _buildTrackingScreen() {
    return Column(
      children: [
        _buildHeader(),
        if (_gpsOff) _buildGpsOffBanner(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SpeedometerGauge(speedKmh: _tripData.currentSpeedKmh),
          ),
        ),
        _buildSpeedLabel(),
        const SizedBox(height: 16),
        if (_tripData.isRecording) _buildElapsedTimer(),
        const SizedBox(height: 16),
        StatsRow(
          maxSpeedKmh: _tripData.maxSpeedKmh,
          avgSpeedKmh: _tripData.avgSpeedKmh,
          distanceMeters: _tripData.distanceMeters,
        ),
        const SizedBox(height: 20),
        _buildTripControls(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildGpsOffBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFD50000).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: const Color(0xFFD50000).withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.gps_off_rounded,
                color: Color(0xFFD50000), size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'GPS is turned off',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () => Geolocator.openLocationSettings(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00E676),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'ENABLE',
                style:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
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
                  color: (noFix || _gpsOff)
                      ? const Color(0xFFD50000)
                      : _accuracyColor(_tripData.gpsAccuracy),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _gpsOff
                    ? 'GPS off'
                    : noFix
                        ? 'Searching...'
                        : '±${_tripData.gpsAccuracy.toStringAsFixed(0)}m',
                style: const TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TripHistoryScreen()),
                ),
                child: const Icon(Icons.history_rounded,
                    color: Color(0xFF9E9E9E), size: 22),
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

  Widget _buildElapsedTimer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFD50000),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatDuration(_elapsed),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTripControls() {
    if (_tripData.isRecording) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _onStopTrip,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD50000),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'STOP TRIP',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _tripData.status == TripStatus.tracking
              ? _onStartTrip
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E676),
            foregroundColor: Colors.black,
            disabledBackgroundColor: const Color(0xFF2D2D44),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(
            _tripData.status == TripStatus.tracking
                ? 'START TRIP'
                : _gpsOff
                    ? 'GPS IS OFF'
                    : 'WAITING FOR GPS',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0),
          ),
        ),
      ),
    );
  }
}
