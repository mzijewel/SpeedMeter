import 'package:flutter/material.dart';

class StatsRow extends StatelessWidget {
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final double distanceMeters;

  const StatsRow({
    super.key,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    required this.distanceMeters,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _StatCard(
            label: 'MAX SPEED',
            value: maxSpeedKmh.toStringAsFixed(1),
            unit: 'km/h',
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'AVG SPEED',
            value: avgSpeedKmh.toStringAsFixed(1),
            unit: 'km/h',
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: 'DISTANCE',
            value: distanceMeters < 1000
                ? distanceMeters.toStringAsFixed(0)
                : (distanceMeters / 1000).toStringAsFixed(1),
            unit: distanceMeters < 1000 ? 'm' : 'km',
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2D2D44), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 10,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              unit,
              style: const TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
