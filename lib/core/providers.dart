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

// ---------------------------------------------------------------------------
// Rol (persistido en SharedPreferences)
// ---------------------------------------------------------------------------

final _prefsProvider = FutureProvider<SharedPreferences>(
    (_) => SharedPreferences.getInstance());

final roleProvider = StateNotifierProvider<RoleNotifier, UserRole?>((ref) {
  final prefs = ref.watch(_prefsProvider).valueOrNull;
  return RoleNotifier(prefs);
});

class RoleNotifier extends StateNotifier<UserRole?> {
  RoleNotifier(this._prefs)
      : super(_prefs != null
            ? _roleFromString(_prefs.getString('user_role'))
            : null);

  final SharedPreferences? _prefs;

  static UserRole? _roleFromString(String? value) {
    if (value == 'pingo') return UserRole.pingo;
    if (value == 'familiar') return UserRole.familiar;
    return null;
  }

  Future<void> setRole(UserRole role) async {
    await _prefs?.setString('user_role', role.name);
    state = role;
  }

  Future<void> clearRole() async {
    await _prefs?.remove('user_role');
    state = null;
  }
}

// ---------------------------------------------------------------------------
// Familiar: configs del usuario autenticado (stream en tiempo real)
// ---------------------------------------------------------------------------

final familiarConfigsProvider = StreamProvider<List<Config>>((ref) {
  final userAsync = ref.watch(authProvider);
  final uid = userAsync.valueOrNull?.uid;
  if (uid == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('configs')
      .where('ownerUid', isEqualTo: uid)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = {...doc.data(), 'id': doc.id};
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
      .map((snap) => snap.exists ? Session.fromJson(snap.data()!) : null);
});

// ---------------------------------------------------------------------------
// Pingo: pairings guardados localmente
// ---------------------------------------------------------------------------

final pingoConfigsProvider =
    StateNotifierProvider<PingoPairingsNotifier, List<PingoPairing>>((ref) {
  final prefs = ref.watch(_prefsProvider).valueOrNull;
  return PingoPairingsNotifier(prefs);
});

class PingoPairingsNotifier extends StateNotifier<List<PingoPairing>> {
  PingoPairingsNotifier(this._prefs) : super(_loadFromPrefs(_prefs));

  final SharedPreferences? _prefs;
  static const _key = 'pingo_pairings';

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
