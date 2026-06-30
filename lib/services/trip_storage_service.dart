import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip.dart';

class TripStorageService {
  static const String _key = 'saved_trips';

  Future<List<Trip>> loadTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) => Trip.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  Future<void> saveTrip(Trip trip) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(jsonEncode(trip.toJson()));
    await prefs.setStringList(_key, raw);
  }

  Future<void> updateTrip(Trip trip) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final encoded = jsonEncode(trip.toJson());
    for (var i = 0; i < raw.length; i++) {
      final map = jsonDecode(raw[i]) as Map<String, dynamic>;
      if (map['id'] == trip.id) {
        raw[i] = encoded;
        break;
      }
    }
    await prefs.setStringList(_key, raw);
  }

  Future<void> deleteTrip(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return map['id'] == id;
    });
    await prefs.setStringList(_key, raw);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Serializes all stored trips into a pretty-printed JSON array string.
  Future<String> exportJson() async {
    final trips = await loadTrips();
    return const JsonEncoder.withIndent('  ')
        .convert(trips.map((t) => t.toJson()).toList());
  }

  /// Imports trips from a JSON array string, skipping any whose id already
  /// exists. Returns the number of trips actually added.
  Future<int> importJson(String content) async {
    final decoded = jsonDecode(content);
    if (decoded is! List) {
      throw const FormatException('Expected a JSON array of trips.');
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final existingIds = raw
        .map((s) => (jsonDecode(s) as Map<String, dynamic>)['id'])
        .toSet();

    var added = 0;
    for (final item in decoded) {
      final trip = Trip.fromJson(item as Map<String, dynamic>);
      if (existingIds.contains(trip.id)) continue;
      raw.add(jsonEncode(trip.toJson()));
      existingIds.add(trip.id);
      added++;
    }
    await prefs.setStringList(_key, raw);
    return added;
  }
}
