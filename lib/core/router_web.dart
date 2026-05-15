import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/familiar/screens/familiar_config_form_screen.dart';
import '../features/familiar/screens/familiar_home_screen.dart';
import '../features/familiar/screens/familiar_live_map_screen.dart';
import '../features/familiar/screens/familiar_qr_screen.dart';
import '../features/familiar/screens/familiar_settings_screen.dart';

final webRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
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
