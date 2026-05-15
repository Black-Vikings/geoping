import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_prefs.dart';

import '../features/familiar/screens/familiar_config_form_screen.dart';
import '../features/familiar/screens/familiar_home_screen.dart';
import '../features/familiar/screens/familiar_live_map_screen.dart';
import '../features/familiar/screens/familiar_qr_screen.dart';
import '../features/familiar/screens/familiar_settings_screen.dart';
import '../features/pingo/screens/pingo_home_screen.dart';
import '../features/pingo/screens/pingo_pair_screen.dart';
import '../features/pingo/screens/pingo_settings_screen.dart';
import '../features/role_selection/role_selection_screen.dart';

String _initialLocation() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return '/';
  if (user.isAnonymous) return '/pingo';
  // Non-anonymous user: use persisted role to distinguish Pingo (linked Google) from Familiar
  final savedRole = appPrefs?.getString('user_role');
  if (savedRole == 'pingo') return '/pingo';
  return '/familiar';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: _initialLocation(),
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/pingo',
        builder: (_, __) => const PingoHomeScreen(),
        routes: [
          GoRoute(
            path: 'pair',
            builder: (_, __) => const PingoPairScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (_, __) => const PingoSettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/familiar',
        name: 'familiar-home',
        builder: (_, __) => const FamiliarHomeScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'familiar-new',
            builder: (_, __) => const FamiliarConfigFormScreen(),
          ),
          GoRoute(
            path: ':configId/qr',
            name: 'familiar-qr',
            builder: (_, state) =>
                FamiliarQrScreen(configId: state.pathParameters['configId']!),
          ),
          GoRoute(
            path: ':configId/map',
            name: 'familiar-map',
            builder: (_, state) => FamiliarLiveMapScreen(
                configId: state.pathParameters['configId']!),
          ),
          GoRoute(
            path: ':configId/settings',
            name: 'familiar-settings',
            builder: (_, state) => FamiliarSettingsScreen(
                configId: state.pathParameters['configId']!),
          ),
        ],
      ),
    ],
  );
});
