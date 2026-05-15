import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

abstract final class BackgroundLocationService {
  static final Map<String, StreamSubscription<Position>> _subscriptions = {};
  static final Map<String, String> _writeTokens = {};

  static void start(String configId, String writeToken) {
    _subscriptions[configId]?.cancel();
    _writeTokens[configId] = writeToken;

    final stream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // only fires when moving ≥10 meters
      ),
    );

    _subscriptions[configId] = stream.listen(
      (position) => _push(configId, position),
      onError: (_) {}, // transient errors — stream will retry
    );
  }

  static void stop(String configId) {
    _subscriptions[configId]?.cancel();
    _subscriptions.remove(configId);
    _writeTokens.remove(configId);
  }

  static Future<void> _push(String configId, Position position) async {
    final writeToken = _writeTokens[configId];
    if (writeToken == null) return;

    try {
      await FirebaseFirestore.instance.doc('sessions/$configId').update({
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'writeToken': writeToken,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // transient error — next position event will retry
    }
  }
}
