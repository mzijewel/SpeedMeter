class Trip {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final double distanceMeters;
  final List<Map<String, double>> waypoints;

  const Trip({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    required this.distanceMeters,
    this.waypoints = const [],
  });

  Duration get duration => endTime.difference(startTime);

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'maxSpeedKmh': maxSpeedKmh,
        'avgSpeedKmh': avgSpeedKmh,
        'distanceMeters': distanceMeters,
        'waypoints': waypoints,
      };

  factory Trip.fromJson(Map<String, dynamic> json) {
    final raw = json['waypoints'] as List<dynamic>?;
    final waypoints = raw
            ?.map((w) {
              final m = w as Map<String, dynamic>;
              return {
                'lat': (m['lat'] as num).toDouble(),
                'lng': (m['lng'] as num).toDouble(),
              };
            })
            .toList() ??
        [];

    return Trip(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      maxSpeedKmh: (json['maxSpeedKmh'] as num).toDouble(),
      avgSpeedKmh: (json['avgSpeedKmh'] as num).toDouble(),
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      waypoints: waypoints,
    );
  }
}
