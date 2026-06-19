import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' hide ServiceStatus;

import '../models/trip.dart';
import '../models/trip_data.dart';

class LocationService {
  // Fixes with worse horizontal accuracy than this (indoor/network/cold-start
  // fixes) produce garbage speed and distance, so they are ignored for both.
  static const double _maxTrustedAccuracyMeters = 50.0;
  // GPS doppler noise while standing still typically reads 0.5–2 km/h.
  static const double _stationaryCutoffKmh = 2.0;
  // Base exponential smoothing factor for the displayed speed. Kept high so the
  // reading tracks the GPS within ~1-2 samples instead of lagging several
  // seconds; small jitter is still damped, while large changes (real accel /
  // braking) snap almost instantly via _snapAlpha below.
  static const double _smoothingAlpha = 0.6;
  // When the new reading differs from the displayed one by more than this, the
  // change is real movement, not noise — apply much heavier weighting so the
  // speedometer responds immediately.
  static const double _snapDeltaKmh = 4.0;
  static const double _snapAlpha = 0.9;

  final StreamController<TripData> _controller =
      StreamController<TripData>.broadcast();

  TripData _data = TripData.initial();
  double _smoothedKmh = 0.0;
  Position? _lastPosition;
  DateTime? _lastFixTime;
  int _sampleCount = 0;
  double _speedAccumulator = 0.0;
  int _movingMillis = 0;
  DateTime? _lastSampleWallTime;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;
  Timer? _fgsWatchdog;
  final List<Map<String, double>> _waypoints = [];
  Map<String, double>? _lastWaypoint;

  Stream<TripData> get tripStream => _controller.stream;

  static LocationSettings _buildLocationSettings({required bool recording}) {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        // Ask for the fastest fixes the hardware will give (the default
        // interval can be several seconds, which is the main source of lag).
        intervalDuration: const Duration(milliseconds: 1000),
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
    _watchServiceStatus();
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
    // Preserve the recording stream config if GPS was toggled mid-trip.
    await _startStream(recording: _data.isRecording);
  }

  // GPS can be toggled at any time; instead of staying stuck on the disabled
  // status, drop the position stream while it's off and re-initialize as soon
  // as the user turns it back on.
  void _watchServiceStatus() {
    _serviceStatusSub ??= Geolocator.getServiceStatusStream().listen((
      ServiceStatus status,
    ) {
      if (status == ServiceStatus.enabled) {
        initialize();
      } else {
        _fgsWatchdog?.cancel();
        _positionSub?.cancel();
        _positionSub = null;
        _emit(_data.copyWith(status: TripStatus.locationServiceDisabled));
      }
    });
  }

  Future<void> _startStream({required bool recording}) async {
    await _positionSub?.cancel();
    _fgsWatchdog?.cancel();
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: _buildLocationSettings(recording: recording),
        ).listen(
          _onPosition,
          onError: (_) {
            // The recording stream attaches an Android foreground service. On OEM
            // skins that block the FGS (MIUI/Xiaomi, etc.) it errors out and stops
            // delivering positions — fall back to a plain stream so the trip keeps
            // recording in the foreground (_data.isRecording still drives distance).
            if (recording && Platform.isAndroid) {
              _startStream(recording: false);
            } else {
              _emit(_data.copyWith(status: TripStatus.noGpsFix));
            }
          },
        );

    // Some devices don't error — the FGS just never starts and the stream
    // goes silent. If we were already getting fixes and none arrive shortly
    // after a recording restart, fall back to a plain stream too.
    if (recording &&
        Platform.isAndroid &&
        _data.status == TripStatus.tracking) {
      _fgsWatchdog = Timer(const Duration(seconds: 8), () {
        _startStream(recording: false);
      });
    }
  }

  void _onPosition(Position position) {
    _fgsWatchdog?.cancel();
    final bool trustedFix = position.accuracy <= _maxTrustedAccuracyMeters;

    // Doppler speed straight from the GPS chip (m/s). Negative means the device
    // couldn't compute it. We trust it as-is — it's far more precise than
    // differentiating position — and only reject it on an untrusted fix. The
    // stationary cutoff below removes standing-still noise; comparing against
    // speedAccuracy here was too aggressive and zeroed out real low speeds.
    final bool hasDopplerSpeed = position.speed >= 0;
    double speedMps = trustedFix && hasDopplerSpeed ? position.speed : 0.0;

    double kmh = speedMps * 3.6;
    if (kmh < _stationaryCutoffKmh) {
      kmh = 0.0;
      speedMps = 0.0;
    }

    final double diff = kmh - _smoothedKmh;
    final double alpha = diff.abs() >= _snapDeltaKmh
        ? _snapAlpha
        : _smoothingAlpha;
    _smoothedKmh += alpha * diff;
    if (_smoothedKmh < 0.5) _smoothedKmh = 0.0;
    final double displayKmh = _smoothedKmh;

    // Distance from point-to-point displacement, with jitter and jump filters.
    // (Doppler-velocity integration was unreliable here — many devices don't
    // advance position.timestamp between fixes, so the time delta read as 0.)
    double deltaMeters = 0;
    final DateTime fixTime = position.timestamp;
    if (trustedFix && _lastPosition != null && _data.isRecording) {
      final double dPos = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      // Reject single-fix jumps that are physically impossible. Use the time
      // gap when the platform gives usable timestamps; otherwise fall back to a
      // hard distance cap so one wild fix can't inject a phantom kilometre.
      final double dt = _lastFixTime != null
          ? fixTime.difference(_lastFixTime!).inMilliseconds / 1000.0
          : 0.0;
      final bool plausible = dt > 0 ? (dPos / dt) <= 70 : dPos <= 150;

      // Movement is real when the doppler speed confirms motion, or when the
      // displacement clearly exceeds the GPS noise floor. This drops the
      // metre-scale jitter that piles up while stopped without losing slow
      // genuine movement.
      final double noiseFloor = max(8.0, position.accuracy * 0.5);
      final bool moving = kmh >= _stationaryCutoffKmh || dPos >= noiseFloor;

      if (plausible && moving) deltaMeters = dPos;
    }
    // Untrusted fixes don't advance the anchors either — otherwise a single
    // indoor fix injects a phantom round-trip into the total.
    if (trustedFix) {
      _lastPosition = position;
      _lastFixTime = fixTime;
    }

    if (trustedFix && _data.isRecording) {
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

    if (_data.isRecording && displayKmh > 1.0) {
      _speedAccumulator += displayKmh;
      _sampleCount++;
    }
    final double avg = _sampleCount > 0
        ? _speedAccumulator / _sampleCount
        : 0.0;

    // Accumulate "moving" time from the wall-clock gap between fixes, but only
    // when this fix actually covered ground (deltaMeters > 0) — the same signal
    // that grows the distance. Paused time is then derived as elapsed - moving
    // by the UI / Trip, so it stays correct even when GPS fixes are sparse
    // (no fixes => no moving time => everything counts as paused). The gap is
    // capped so a GPS dropout can't dump a large block into the moving total.
    final DateTime now = DateTime.now();
    if (_data.isRecording && _lastSampleWallTime != null && deltaMeters > 0) {
      final int gapMs = now.difference(_lastSampleWallTime!).inMilliseconds;
      if (gapMs > 0) _movingMillis += gapMs.clamp(0, 5000);
    }
    _lastSampleWallTime = now;

    _data = _data.copyWith(
      currentSpeedKmh: displayKmh,
      maxSpeedKmh: _data.isRecording
          ? max(_data.maxSpeedKmh, displayKmh)
          : _data.maxSpeedKmh,
      avgSpeedKmh: _data.isRecording ? avg : _data.avgSpeedKmh,
      distanceMeters: _data.distanceMeters + deltaMeters,
      gpsAccuracy: position.accuracy,
      status: TripStatus.tracking,
      movingDuration: Duration(milliseconds: _movingMillis),
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
    _lastFixTime = null;
    _sampleCount = 0;
    _speedAccumulator = 0.0;
    _movingMillis = 0;
    _lastSampleWallTime = null;
    _waypoints.clear();
    _lastWaypoint = null;
    _data = _data.copyWith(
      maxSpeedKmh: 0,
      avgSpeedKmh: 0,
      distanceMeters: 0,
      isRecording: true,
      recordingStartedAt: DateTime.now(),
      movingDuration: Duration.zero,
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
      movingDuration: Duration(milliseconds: _movingMillis),
    );

    _lastPosition = null;
    _lastFixTime = null;
    _sampleCount = 0;
    _speedAccumulator = 0.0;
    _movingMillis = 0;
    _lastSampleWallTime = null;
    _waypoints.clear();
    _lastWaypoint = null;
    _data = _data.copyWith(
      maxSpeedKmh: 0,
      avgSpeedKmh: 0,
      distanceMeters: 0,
      isRecording: false,
      clearRecordingStart: true,
      movingDuration: Duration.zero,
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
    _serviceStatusSub?.cancel();
    _positionSub?.cancel();
    _controller.close();
  }
}
