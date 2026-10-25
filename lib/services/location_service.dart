import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class PositionResult {
  final double latitude;
  final double longitude;
  final bool isAvailable;

  const PositionResult({
    required this.latitude,
    required this.longitude,
    required this.isAvailable,
  });

  // 0.0 / 0.0 is what ScanRecord treats as "no GPS fix"
  const PositionResult.unavailable()
      : latitude = 0.0,
        longitude = 0.0,
        isAvailable = false;
}

class LocationService {
  // Never throws. A scan should still be saved when GPS is off, denied,
  // or slow, so every failure returns an unavailable result.
  static Future<PositionResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const PositionResult.unavailable();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const PositionResult.unavailable();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return PositionResult(
        latitude: position.latitude,
        longitude: position.longitude,
        isAvailable: true,
      );
    } catch (e) {
      debugPrint('LocationService error: $e');
      return _lastKnownOrUnavailable();
    }
  }

  static Future<PositionResult> _lastKnownOrUnavailable() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return PositionResult(
          latitude: last.latitude,
          longitude: last.longitude,
          isAvailable: true,
        );
      }
    } catch (e) {
      debugPrint('LocationService fallback error: $e');
    }
    return const PositionResult.unavailable();
  }
}
