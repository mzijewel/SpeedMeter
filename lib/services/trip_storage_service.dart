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
}
