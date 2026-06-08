import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart';

import '../models/trip.dart';
import '../models/trip_data.dart';

class LocationService {
  final StreamController<TripData> _controller =
      StreamController<TripData>.broadcast();

  TripData _data = TripData.initial();
  Position? _lastPosition;
  int _sampleCount = 0;
  double _speedAccumulator = 0.0;
  StreamSubscription<Position>? _positionSub;
  final List<Map<String, double>> _waypoints = [];
  Map<String, double>? _lastWaypoint;

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
    if (_lastPosition != null && _data.isRecording) {
      final double delta = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (delta <= 500) {
        if (delta >= 2.0 || kmh >= 1.0) {
          deltaMeters = delta;
        }
      }
    }
    _lastPosition = position;

    if (_data.isRecording) {
      if (_lastWaypoint == null) {
        _recordWaypoint(position);
      } else {
        final dist = Geolocator.distanceBetween(
          _lastWaypoint!['lat']!,
          _lastWaypoint!['lng']!,
          position.latitude,
          position.longitude,
        );
        if (dist >= 10) _recordWaypoint(position);
      }
    }

    if (_data.isRecording && kmh > 1.0) {
      _speedAccumulator += kmh;
      _sampleCount++;
    }
    final double avg =
        _sampleCount > 0 ? _speedAccumulator / _sampleCount : 0.0;

    _data = _data.copyWith(
      currentSpeedKmh: kmh,
      maxSpeedKmh: _data.isRecording ? max(_data.maxSpeedKmh, kmh) : _data.maxSpeedKmh,
      avgSpeedKmh: _data.isRecording ? avg : _data.avgSpeedKmh,
      distanceMeters: _data.distanceMeters + deltaMeters,
      gpsAccuracy: position.accuracy,
      status: TripStatus.tracking,
    );
    _emit(_data);
  }

  void _recordWaypoint(Position pos) {
    final wp = {'lat': pos.latitude, 'lng': pos.longitude};
    _waypoints.add(wp);
    _lastWaypoint = wp;
  }

  void startTrip() {
    _lastPosition = null;
    _sampleCount = 0;
    _speedAccumulator = 0.0;
    _waypoints.clear();
    _lastWaypoint = null;
    _data = _data.copyWith(
      maxSpeedKmh: 0,
      avgSpeedKmh: 0,
      distanceMeters: 0,
      isRecording: true,
      recordingStartedAt: DateTime.now(),
    );
    _emit(_data);
  }

  Trip? stopTrip() {
    if (!_data.isRecording || _data.recordingStartedAt == null) return null;

    final trip = Trip(
      id: _data.recordingStartedAt!.millisecondsSinceEpoch.toString(),
      startTime: _data.recordingStartedAt!,
      endTime: DateTime.now(),
      maxSpeedKmh: _data.maxSpeedKmh,
      avgSpeedKmh: _data.avgSpeedKmh,
      distanceMeters: _data.distanceMeters,
      waypoints: List.from(_waypoints),
    );

    _lastPosition = null;
    _sampleCount = 0;
    _speedAccumulator = 0.0;
    _waypoints.clear();
    _lastWaypoint = null;
    _data = _data.copyWith(
      maxSpeedKmh: 0,
      avgSpeedKmh: 0,
      distanceMeters: 0,
      isRecording: false,
      clearRecordingStart: true,
    );
    _emit(_data);

    return trip;
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
