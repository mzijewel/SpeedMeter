enum TripStatus {
  initializing,
  permissionDenied,
  permissionPermanentlyDenied,
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

  const TripData({
    required this.currentSpeedKmh,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    required this.distanceMeters,
    required this.gpsAccuracy,
    required this.status,
  });

  factory TripData.initial() => const TripData(
        currentSpeedKmh: 0,
        maxSpeedKmh: 0,
        avgSpeedKmh: 0,
        distanceMeters: 0,
        gpsAccuracy: 999,
        status: TripStatus.initializing,
      );

  TripData copyWith({
    double? currentSpeedKmh,
    double? maxSpeedKmh,
    double? avgSpeedKmh,
    double? distanceMeters,
    double? gpsAccuracy,
    TripStatus? status,
  }) {
    return TripData(
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      avgSpeedKmh: avgSpeedKmh ?? this.avgSpeedKmh,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      status: status ?? this.status,
    );
  }
}
