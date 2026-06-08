import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart';

import '../models/trip_data.dart';

class LocationService {
  final StreamController<TripData> _controller =
      StreamController<TripData>.broadcast();

  TripData _data = TripData.initial();
  Position? _lastPosition;
  int _sampleCount = 0;
  double _speedAccumulator = 0.0;
  StreamSubscription<Position>? _positionSub;

  Stream<TripData> get tripStream => _controller.stream;

  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 0,
  );

  Future<void> initialize() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      _emit(_data.copyWith(status: TripStatus.permissionPermanentlyDenied));
      return;
    }
    if (permission == LocationPermission.denied) {
      _emit(_data.copyWith(status: TripStatus.permissionDenied));
      return;
    }

    _emit(_data.copyWith(status: TripStatus.noGpsFix));
    _startStream();
  }

  void _startStream() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(_onPosition, onError: (_) {});
  }

  void _onPosition(Position position) {
    final double rawSpeed = position.speed < 0 ? 0.0 : position.speed;
    final double kmh = rawSpeed * 3.6;

    double deltaMeters = 0;
    if (_lastPosition != null) {
      final double delta = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      // Skip GPS reconnect jumps and sub-2m noise while stationary
      if (delta <= 500) {
        if (delta >= 2.0 || kmh >= 1.0) {
          deltaMeters = delta;
        }
      }
    }
    _lastPosition = position;

    if (kmh > 1.0) {
      _speedAccumulator += kmh;
      _sampleCount++;
    }
    final double avg =
        _sampleCount > 0 ? _speedAccumulator / _sampleCount : 0.0;

    _data = _data.copyWith(
      currentSpeedKmh: kmh,
      maxSpeedKmh: max(_data.maxSpeedKmh, kmh),
      avgSpeedKmh: avg,
      distanceMeters: _data.distanceMeters + deltaMeters,
      gpsAccuracy: position.accuracy,
      status: TripStatus.tracking,
    );
    _emit(_data);
  }

  void resetTrip() {
    _lastPosition = null;
    _sampleCount = 0;
    _speedAccumulator = 0.0;
    _data = _data.copyWith(
      maxSpeedKmh: 0,
      avgSpeedKmh: 0,
      distanceMeters: 0,
    );
    _emit(_data);
  }

  Future<void> retryPermission() async {
    _data = TripData.initial();
    await initialize();
  }

  void _emit(TripData data) {
    _data = data;
    if (!_controller.isClosed) {
      _controller.add(data);
    }
  }

  void dispose() {
    _positionSub?.cancel();
    _controller.close();
  }
}
