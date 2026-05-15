import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/pingo/screens/pingo_home_screen.dart';
import '../features/pingo/screens/pingo_pair_screen.dart';
import '../features/pingo/screens/pingo_settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/pingo',
    routes: [
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
    ],
  );
});
