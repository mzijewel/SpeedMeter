enum TripStatus {
  initializing,
  permissionDenied,
  permissionPermanentlyDenied,
  locationServiceDisabled,
  noGpsFix,
  tracking,
}

class TripData {
  final double currentSpeedKmh;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final double distanceMeters;
  final double gpsAccuracy;
  final TripStatus status;
  final bool isRecording;
  final DateTime? recordingStartedAt;
  // Accumulated time the vehicle was actually moving (covering ground) during
  // the current recording. Paused time is derived as elapsed - moving so it
  // stays correct even when GPS fixes are sparse.
  final Duration movingDuration;

  const TripData({
    required this.currentSpeedKmh,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    required this.distanceMeters,
    required this.gpsAccuracy,
    required this.status,
    this.isRecording = false,
    this.recordingStartedAt,
    this.movingDuration = Duration.zero,
  });

  factory TripData.initial() => const TripData(
        currentSpeedKmh: 0,
        maxSpeedKmh: 0,
        avgSpeedKmh: 0,
        distanceMeters: 0,
        gpsAccuracy: 999,
        status: TripStatus.initializing,
        isRecording: false,
      );

  TripData copyWith({
    double? currentSpeedKmh,
    double? maxSpeedKmh,
    double? avgSpeedKmh,
    double? distanceMeters,
    double? gpsAccuracy,
    TripStatus? status,
    bool? isRecording,
    DateTime? recordingStartedAt,
    bool clearRecordingStart = false,
    Duration? movingDuration,
  }) {
    return TripData(
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      avgSpeedKmh: avgSpeedKmh ?? this.avgSpeedKmh,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      status: status ?? this.status,
      isRecording: isRecording ?? this.isRecording,
      recordingStartedAt: clearRecordingStart
          ? null
          : (recordingStartedAt ?? this.recordingStartedAt),
      movingDuration: movingDuration ?? this.movingDuration,
    );
  }
}
