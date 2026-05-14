import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/familiar/screens/familiar_config_form_screen.dart';
import '../features/familiar/screens/familiar_home_screen.dart';
import '../features/familiar/screens/familiar_live_map_screen.dart';
import '../features/familiar/screens/familiar_qr_screen.dart';
import '../features/familiar/screens/familiar_settings_screen.dart';
import '../features/pingo/screens/pingo_home_screen.dart';
import '../features/pingo/screens/pingo_pair_screen.dart';
import '../features/pingo/screens/pingo_settings_screen.dart';
import '../features/role_selection/role_selection_screen.dart';
import 'models/user_role.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/role',
    redirect: (context, state) {
      final role = ref.read(roleProvider);
      final onRole = state.matchedLocation == '/role';

      if (role == null) return onRole ? null : '/role';
      if (role == UserRole.pingo && onRole) return '/pingo';
      if (role == UserRole.familiar && onRole) return '/familiar';
      return null;
    },
    refreshListenable: _RoleListenable(ref),
    routes: [
      GoRoute(
        path: '/role',
        builder: (_, __) => const RoleSelectionScreen(),
      ),

      // Pingo
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

      // Familiar
      GoRoute(
        path: '/familiar',
        builder: (_, __) => const FamiliarHomeScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, __) => const FamiliarConfigFormScreen(),
          ),
          GoRoute(
            path: ':configId/qr',
            builder: (_, state) =>
                FamiliarQrScreen(configId: state.pathParameters['configId']!),
          ),
          GoRoute(
            path: ':configId/map',
            builder: (_, state) => FamiliarLiveMapScreen(
                configId: state.pathParameters['configId']!),
          ),
          GoRoute(
            path: ':configId/settings',
            builder: (_, state) => FamiliarSettingsScreen(
                configId: state.pathParameters['configId']!),
          ),
        ],
      ),
    ],
  );
});

class _RoleListenable extends ChangeNotifier {
  _RoleListenable(Ref ref) {
    ref.listen(roleProvider, (_, __) => notifyListeners());
  }
}
