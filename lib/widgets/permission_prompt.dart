import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/trip_data.dart';

class PermissionPrompt extends StatelessWidget {
  final TripStatus status;
  final VoidCallback onRetry;

  const PermissionPrompt({
    super.key,
    required this.status,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final bool isServiceDisabled =
        status == TripStatus.locationServiceDisabled;
    final bool isPermanent =
        status == TripStatus.permissionPermanentlyDenied;

    final String title = isServiceDisabled
        ? 'GPS is Turned Off'
        : isPermanent
            ? 'Location Permission Required'
            : 'Allow Location Access';

    final String message = isServiceDisabled
        ? 'Please enable Location/GPS in your device settings to use Speed Meter.'
        : isPermanent
            ? 'Location permission was denied. Please enable it in your device settings to use Speed Meter.'
            : 'Speed Meter needs location access to track your speed and distance.';

    final String buttonLabel = isServiceDisabled
        ? 'OPEN LOCATION SETTINGS'
        : isPermanent
            ? 'OPEN SETTINGS'
            : 'GRANT PERMISSION';

    final VoidCallback buttonAction = isServiceDisabled
        ? () => Geolocator.openLocationSettings()
        : isPermanent
            ? () => Geolocator.openAppSettings()
            : onRetry;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isServiceDisabled ? Icons.gps_off_rounded : Icons.location_off_rounded,
              size: 72,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: buttonAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            if (!isServiceDisabled && !isPermanent) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry,
                child: const Text(
                  'TRY AGAIN',
                  style: TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
