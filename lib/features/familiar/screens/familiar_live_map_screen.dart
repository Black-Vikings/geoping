import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';

class FamiliarLiveMapScreen extends ConsumerWidget {
  const FamiliarLiveMapScreen({super.key, required this.configId});
  final String configId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionProvider(configId));
    final configsAsync = ref.watch(familiarConfigsProvider);

    final elderName = configsAsync.valueOrNull
        ?.where((c) => c.id == configId)
        .firstOrNull
        ?.elderName ??
        '';

    return Scaffold(
      appBar: AppBar(
        title: Text(elderName.isEmpty ? S.verMapa : elderName),
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${S.errorConexion}: $e')),
        data: (session) {
          if (session == null || !session.active) {
            return const Center(
              child: Text(S.sinSesion, style: TextStyle(fontSize: 18)),
            );
          }

          final point = LatLng(session.lat, session.lng);

          return FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 16,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.geopping.geopping',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 80,
                    height: 80,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.location_pin,
                          color: AppTheme.colorBotonAbuelo,
                          size: 48,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(40),
                                blurRadius: 4,
                              )
                            ],
                          ),
                          child: Text(
                            elderName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
