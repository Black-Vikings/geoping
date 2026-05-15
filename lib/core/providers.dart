import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_prefs.dart';
import 'models/config.dart';
import 'models/pingo_pairing.dart';
import 'models/session.dart';
import 'models/user_role.dart';

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

final authProvider = StreamProvider<User?>(
    (ref) => FirebaseAuth.instance.userChanges());

final _prefsProvider = FutureProvider<SharedPreferences>(
    (_) => SharedPreferences.getInstance());

// ---------------------------------------------------------------------------
// Role selection (mobile only)
// ---------------------------------------------------------------------------

final roleProvider = NotifierProvider<RoleNotifier, UserRole?>(RoleNotifier.new);

class RoleNotifier extends Notifier<UserRole?> {
  static const _key = 'user_role';

  @override
  UserRole? build() {
    final saved = appPrefs?.getString(_key);
    return saved != null ? UserRole.values.byName(saved) : null;
  }

  void setRole(UserRole role) {
    appPrefs?.setString(_key, role.name);
    state = role;
  }

  void clearRole() {
    appPrefs?.remove(_key);
    state = null;
  }
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
// Pingo: pairings — local (anónimo) o Firestore (Google)
// ---------------------------------------------------------------------------

final pingoConfigsProvider =
    NotifierProvider<PingoPairingsNotifier, List<PingoPairing>>(PingoPairingsNotifier.new);

class PingoPairingsNotifier extends Notifier<List<PingoPairing>> {
  static const _prefsKey = 'pingo_pairings';
  static const _firestoreField = 'pingoPairings';

  // Prevents a stale _loadFromFirestore from overwriting state during migration.
  bool _migrating = false;

  SharedPreferences? get _prefs => ref.read(_prefsProvider).value;

  @override
  List<PingoPairing> build() {
    final user = ref.watch(authProvider).value;

    if (user != null && !user.isAnonymous) {
      _loadFromFirestore(user.uid);
      return [];
    }

    return _loadFromPrefs(ref.watch(_prefsProvider).value);
  }

  Future<void> _loadFromFirestore(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.doc('users/$uid').get();
      if (_migrating) return;
      if (doc.exists) {
        final raw =
            (doc.data()?[_firestoreField] as List<dynamic>?) ?? [];
        state = raw
            .map((e) =>
                PingoPairing.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
  }

  static List<PingoPairing> _loadFromPrefs(SharedPreferences? prefs) {
    final raw = prefs?.getStringList(_prefsKey) ?? [];
    return raw
        .map((e) => PingoPairing.fromJson(
            Map<String, dynamic>.from(jsonDecode(e) as Map)))
        .toList();
  }

  bool get _isGoogleUser {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && !user.isAnonymous;
  }

  Future<void> addPairing(PingoPairing pairing) async {
    final updated = [...state, pairing];
    await _save(updated);
    state = updated;
  }

  Future<void> removePairing(String configId) async {
    final updated = state.where((p) => p.configId != configId).toList();
    await _save(updated);
    state = updated;
  }

  Future<void> _save(List<PingoPairing> list) async {
    if (_isGoogleUser) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.doc('users/$uid').set(
        {_firestoreField: list.map((p) => p.toJson()).toList()},
        SetOptions(merge: true),
      );
    } else {
      await _persistLocally(list);
    }
  }

  Future<void> _persistLocally(List<PingoPairing> list) async {
    final raw = list.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs?.setStringList(_prefsKey, raw);
  }

  /// Migrates local pairings to Firestore after linking a Google account.
  /// Call this right after [FirebaseAuth.currentUser.linkWithProvider] succeeds.
  Future<void> migrateLocalToFirestore(
      String uid, List<PingoPairing> localPairings) async {
    _migrating = true;
    try {
      await FirebaseFirestore.instance.doc('users/$uid').set(
        {_firestoreField: localPairings.map((p) => p.toJson()).toList()},
        SetOptions(merge: true),
      );
      await _prefs?.remove(_prefsKey);
      state = localPairings;
    } finally {
      _migrating = false;
    }
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
