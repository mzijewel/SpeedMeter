import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

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
  Timer? _fgsWatchdog;
  final List<Map<String, double>> _waypoints = [];
  Map<String, double>? _lastWaypoint;

  Stream<TripData> get tripStream => _controller.stream;

  static LocationSettings _buildLocationSettings({required bool recording}) {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        foregroundNotificationConfig: recording
            ? const ForegroundNotificationConfig(
                notificationText: 'Recording your trip...',
                notificationTitle: 'Speed Meter',
                enableWakeLock: true,
                setOngoing: true,
                notificationChannelName: 'Speed Meter Location',
              )
            : null,
      );
    }
    if (Platform.isIOS) {
      // allowBackgroundLocationUpdates is always true so the stream never
      // needs to be restarted when recording starts. showBackgroundLocationIndicator
      // shows the blue bar only while actively recording.
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: recording,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  Future<void> initialize() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _emit(_data.copyWith(status: TripStatus.locationServiceDisabled));
      return;
    }

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

    // At this point we have at least "while in use". Reliable long-running
    // background tracking needs "Always" (background) authorization:
    //  - iOS suspends background location updates without "Always".
    //  - Android 10+ needs ACCESS_BACKGROUND_LOCATION ("Allow all the time").
    // Requesting again escalates whileInUse -> always (geolocator routes the
    // user to the system dialog / settings page as required by the platform).
    if (permission == LocationPermission.whileInUse) {
      final LocationPermission upgraded = await Geolocator.requestPermission();
      if (upgraded == LocationPermission.always) {
        permission = upgraded;
      }
    }

    // Android 13+ needs runtime notification permission for the
    // foreground-service notification to actually show; a visible ongoing
    // notification is what keeps the location service alive in the background.
    // Also ask the OS to exempt us from battery optimization (Doze) so the
    // foreground service is not throttled/killed during long trips. On
    // aggressive OEM skins (Xiaomi/MIUI, etc.) the user must additionally
    // enable "Autostart" and set battery usage to "No restrictions" by hand —
    // those cannot be toggled programmatically.
    if (Platform.isAndroid) {
      await Permission.notification.request();
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }

    _emit(_data.copyWith(status: TripStatus.noGpsFix));
    await _startStream(recording: false);
  }

  Future<void> _startStream({required bool recording}) async {
    await _positionSub?.cancel();
    _fgsWatchdog?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(recording: recording),
    ).listen(_onPosition, onError: (_) {
      // The recording stream attaches an Android foreground service. On OEM
      // skins that block the FGS (MIUI/Xiaomi, etc.) it errors out and stops
      // delivering positions — fall back to a plain stream so the trip keeps
      // recording in the foreground (_data.isRecording still drives distance).
      if (recording && Platform.isAndroid) {
        _startStream(recording: false);
      } else {
        _emit(_data.copyWith(status: TripStatus.noGpsFix));
      }
    });

    // Some devices don't error — the FGS just never starts and the stream
    // goes silent. If we were already getting fixes and none arrive shortly
    // after a recording restart, fall back to a plain stream too.
    if (recording && Platform.isAndroid &&
        _data.status == TripStatus.tracking) {
      _fgsWatchdog = Timer(const Duration(seconds: 8), () {
        _startStream(recording: false);
      });
    }
  }

  void _onPosition(Position position) {
    _fgsWatchdog?.cancel();
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
        if (dist >= 5) _recordWaypoint(position);
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
    // Android needs a stream restart to attach the foreground service
    // notification. iOS keeps the same stream (allowBackgroundLocationUpdates
    // is already true from initialize()).
    if (Platform.isAndroid) _startStream(recording: true);
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
    if (Platform.isAndroid) _startStream(recording: false);

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
    _fgsWatchdog?.cancel();
    _positionSub?.cancel();
    _controller.close();
  }
}
