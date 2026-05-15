import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/config.dart';
import 'models/pingo_pairing.dart';
import 'models/session.dart';
import 'models/user_role.dart';

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

final authProvider = StreamProvider<User?>(
    (ref) => FirebaseAuth.instance.authStateChanges());

final _prefsProvider = FutureProvider<SharedPreferences>(
    (_) => SharedPreferences.getInstance());

// ---------------------------------------------------------------------------
// Role selection (mobile only)
// ---------------------------------------------------------------------------

final roleProvider = NotifierProvider<RoleNotifier, UserRole?>(RoleNotifier.new);

class RoleNotifier extends Notifier<UserRole?> {
  @override
  UserRole? build() => null;

  void setRole(UserRole role) => state = role;
}

// ---------------------------------------------------------------------------
// Familiar: configs del usuario autenticado (stream en tiempo real)
// ---------------------------------------------------------------------------

final familiarConfigsProvider = StreamProvider<List<Config>>((ref) {
  final userAsync = ref.watch(authProvider);
  final uid = userAsync.value?.uid;
  if (uid == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('configs')
      .where('ownerUid', isEqualTo: uid)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = _convertTimestamps({...doc.data(), 'id': doc.id});
            return Config.fromJson(data);
          }).toList());
});

// ---------------------------------------------------------------------------
// Sesión activa de un config específico (stream en tiempo real)
// ---------------------------------------------------------------------------

final sessionProvider =
    StreamProvider.family<Session?, String>((ref, configId) {
  return FirebaseFirestore.instance
      .doc('sessions/$configId')
      .snapshots()
      .map((snap) =>
          snap.exists ? Session.fromJson(_convertTimestamps(snap.data()!)) : null);
});

// ---------------------------------------------------------------------------
// Pingo: pairings guardados localmente
// ---------------------------------------------------------------------------

final pingoConfigsProvider =
    NotifierProvider<PingoPairingsNotifier, List<PingoPairing>>(PingoPairingsNotifier.new);

class PingoPairingsNotifier extends Notifier<List<PingoPairing>> {
  static const _key = 'pingo_pairings';

  SharedPreferences? get _prefs => ref.read(_prefsProvider).value;

  @override
  List<PingoPairing> build() {
    final prefs = ref.watch(_prefsProvider).value;
    return _loadFromPrefs(prefs);
  }

  static List<PingoPairing> _loadFromPrefs(SharedPreferences? prefs) {
    final raw = prefs?.getStringList(_key) ?? [];
    return raw
        .map((e) => PingoPairing.fromJson(
            Map<String, dynamic>.from(jsonDecode(e) as Map)))
        .toList();
  }

  Future<void> addPairing(PingoPairing pairing) async {
    final updated = [...state, pairing];
    await _persist(updated);
    state = updated;
  }

  Future<void> removePairing(String configId) async {
    final updated = state.where((p) => p.configId != configId).toList();
    await _persist(updated);
    state = updated;
  }

  Future<void> _persist(List<PingoPairing> list) async {
    final raw = list.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs?.setStringList(_key, raw);
  }
}

// Converts Firestore Timestamps to ISO 8601 strings so json_serializable can parse them.
Map<String, dynamic> _convertTimestamps(Map<String, dynamic> data) {
  return data.map((key, value) {
    if (value is Timestamp) return MapEntry(key, value.toDate().toIso8601String());
    if (value is Map<String, dynamic>) return MapEntry(key, _convertTimestamps(value));
    return MapEntry(key, value);
  });
}
