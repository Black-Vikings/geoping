import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../services/background_service.dart';
import 'session_state.dart';

// One notifier per configId so each familiar button has independent state.
final sessionNotifierProvider =
    NotifierProvider.family<SessionNotifier, SessionState, String>(
        (configId) => SessionNotifier(configId));

class SessionNotifier extends Notifier<SessionState> {
  SessionNotifier(this._configId);

  final String _configId;

  @override
  SessionState build() => const SessionState.idle();

  Future<void> startSession(String writeToken) async {
    state = const SessionState.starting();
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      final position = await _getCurrentPosition();
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 1));

      await FirebaseFirestore.instance.doc('sessions/$_configId').set({
        'active': true,
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'writeToken': writeToken,
        'updatedAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(expiresAt),
      });

      BackgroundLocationService.start(_configId, writeToken);

      state = SessionState.active(
        configId: _configId,
        expiresAt: expiresAt,
      );
    } catch (e) {
      state = SessionState.error(e.toString());
    }
  }

  Future<void> stopSession() async {
    BackgroundLocationService.stop(_configId);
    await FirebaseFirestore.instance.doc('sessions/$_configId').update({
      'active': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    state = const SessionState.idle();
  }

  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Servicio de ubicación desactivado');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permiso de ubicación denegado');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación denegado permanentemente');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}
