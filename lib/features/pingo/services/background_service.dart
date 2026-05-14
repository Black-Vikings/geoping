import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

abstract final class BackgroundLocationService {
  static final Map<String, Timer> _timers = {};
  static final Map<String, String> _writeTokens = {};

  static void start(String configId, String writeToken) {
    _timers[configId]?.cancel();
    _writeTokens[configId] = writeToken;
    _timers[configId] =
        Timer.periodic(const Duration(seconds: 30), (_) => _push(configId));
  }

  static void stop(String configId) {
    _timers[configId]?.cancel();
    _timers.remove(configId);
    _writeTokens.remove(configId);
  }

  static Future<void> _push(String configId) async {
    final writeToken = _writeTokens[configId];
    if (writeToken == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await FirebaseFirestore.instance.doc('sessions/$configId').update({
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'writeToken': writeToken,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Transient error — next tick will retry
    }
  }
}
