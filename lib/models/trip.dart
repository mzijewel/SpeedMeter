class Trip {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final double distanceMeters;

  const Trip({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    required this.distanceMeters,
  });

  Duration get duration => endTime.difference(startTime);

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'maxSpeedKmh': maxSpeedKmh,
        'avgSpeedKmh': avgSpeedKmh,
        'distanceMeters': distanceMeters,
      };

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: DateTime.parse(json['endTime'] as String),
        maxSpeedKmh: (json['maxSpeedKmh'] as num).toDouble(),
        avgSpeedKmh: (json['avgSpeedKmh'] as num).toDouble(),
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
      );
}
