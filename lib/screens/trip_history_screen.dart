import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/trip.dart';
import '../services/trip_storage_service.dart';
import 'trip_map_screen.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final TripStorageService _storage = TripStorageService();
  List<Trip> _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trips = await _storage.loadTrips();
    if (mounted) setState(() { _trips = trips; _loading = false; });
  }

  Future<void> _delete(String id) async {
    await _storage.deleteTrip(id);
    if (mounted) setState(() => _trips.removeWhere((t) => t.id == id));
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Clear all trips?',
            style: TextStyle(color: Colors.white)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: Color(0xFF9E9E9E))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL',
                style: TextStyle(color: Color(0xFF9E9E9E))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CLEAR',
                style: TextStyle(color: Color(0xFFD50000))),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _storage.clearAll();
      if (mounted) setState(() => _trips.clear());
    }
  }

  Future<void> _share() async {
    try {
      final json = await _storage.exportJson();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/trip_history.json');
      await file.writeAsString(json);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Trip History',
      );
    } catch (e) {
      _showSnack('Could not share trips: $e');
    }
  }

  Future<void> _restore() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final bytes = picked.bytes;
      final content = bytes != null
          ? String.fromCharCodes(bytes)
          : await File(picked.path!).readAsString();

      final added = await _storage.importJson(content);
      await _load();
      _showSnack(added > 0
          ? 'Restored $added trip${added == 1 ? '' : 's'}.'
          : 'No new trips to restore.');
    } on FormatException catch (e) {
      _showSnack('Invalid trip file: ${e.message}');
    } catch (e) {
      _showSnack('Could not restore trips: $e');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1A1A2E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        foregroundColor: Colors.white,
        title: const Text(
          'TRIP HISTORY',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: const Color(0xFF1A1A2E),
            onSelected: (value) {
              switch (value) {
                case 'share':
                  _share();
                  break;
                case 'restore':
                  _restore();
                  break;
                case 'clear':
                  _clearAll();
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'share',
                enabled: _trips.isNotEmpty,
                child: const _MenuRow(
                  icon: Icons.ios_share,
                  label: 'Share',
                ),
              ),
              const PopupMenuItem(
                value: 'restore',
                child: _MenuRow(
                  icon: Icons.restore,
                  label: 'Restore',
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                enabled: _trips.isNotEmpty,
                child: const _MenuRow(
                  icon: Icons.delete_sweep_outlined,
                  label: 'Clear all',
                  color: Color(0xFFD50000),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : _trips.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _trips.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _TripCard(
                    trip: _trips[i],
                    onDelete: () => _delete(_trips[i].id),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TripMapScreen(trip: _trips[i]),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.route_outlined,
              size: 64, color: Color(0xFF2D2D44)),
          SizedBox(height: 16),
          Text('No trips recorded yet',
              style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 16)),
          SizedBox(height: 8),
          Text('Start a trip from the main screen',
              style: TextStyle(color: Color(0xFF555566), fontSize: 13)),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _TripCard({required this.trip, required this.onDelete, required this.onTap});

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(trip.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Delete this trip?',
              style: TextStyle(color: Colors.white)),
          content: const Text('This cannot be undone.',
              style: TextStyle(color: Color(0xFF9E9E9E))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL',
                  style: TextStyle(color: Color(0xFF9E9E9E))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('DELETE',
                  style: TextStyle(color: Color(0xFFD50000))),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFD50000),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2D2D44), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(trip.startTime),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatDuration(trip.duration),
                  style: const TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(label: 'DISTANCE', value: _formatDistance(trip.distanceMeters)),
                _Stat(label: 'MAX SPEED', value: '${trip.maxSpeedKmh.toStringAsFixed(1)} km/h'),
                _Stat(label: 'AVG SPEED', value: '${trip.avgSpeedKmh.toStringAsFixed(1)} km/h'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(label: 'MOVING', value: _formatDuration(trip.movingDuration)),
                _Stat(label: 'PAUSED', value: _formatDuration(trip.pausedDuration)),
                const _Stat(label: '', value: ''),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MenuRow({
    required this.icon,
    required this.label,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9E9E9E), fontSize: 10, letterSpacing: 0.6)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
