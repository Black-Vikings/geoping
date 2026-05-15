import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';

class _GeoAddress {
  const _GeoAddress({
    required this.display,
    this.road,
    this.houseNumber,
    this.neighbourhood,
    this.suburb,
    this.city,
    this.state,
    this.postcode,
  });

  final String display;
  final String? road;
  final String? houseNumber;
  final String? neighbourhood;
  final String? suburb;
  final String? city;
  final String? state;
  final String? postcode;

  String get streetLine {
    final parts = [if (road != null) road!, if (houseNumber != null) houseNumber!];
    return parts.join(' ');
  }

  String get localityLine {
    final parts = [
      if (neighbourhood != null) neighbourhood!,
      if (suburb != null && suburb != neighbourhood) suburb!,
    ];
    return parts.join(', ');
  }

  String get cityLine {
    final parts = [
      if (city != null) city!,
      if (state != null) state!,
      if (postcode != null) postcode!,
    ];
    return parts.join(', ');
  }
}

// Reverse geocoding via Nominatim — keyed by rounded coords (~100 m precision)
final _addressProvider =
    FutureProvider.family<_GeoAddress, (double, double)>((ref, coords) async {
  final (lat, lng) = coords;
  final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
    'lat': lat.toString(),
    'lon': lng.toString(),
    'format': 'json',
    'addressdetails': '1',
  });
  try {
    final res = await http.get(uri, headers: {'Accept-Language': 'es'});
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>? ?? {};
      return _GeoAddress(
        display: (data['display_name'] as String?) ?? '',
        road: addr['road'] as String? ?? addr['pedestrian'] as String?,
        houseNumber: addr['house_number'] as String?,
        neighbourhood: addr['neighbourhood'] as String?
            ?? addr['quarter'] as String?
            ?? addr['hamlet'] as String?,
        suburb: addr['suburb'] as String?
            ?? addr['city_district'] as String?
            ?? addr['village'] as String?,
        city: addr['city'] as String?
            ?? addr['town'] as String?
            ?? addr['municipality'] as String?,
        state: addr['state'] as String?,
        postcode: addr['postcode'] as String?,
      );
    }
  } catch (_) {}
  return _GeoAddress(display: '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}');
});

(double, double) _roundedCoords(double lat, double lng) =>
    ((lat * 1000).round() / 1000, (lng * 1000).round() / 1000);

class FamiliarLiveMapScreen extends ConsumerWidget {
  const FamiliarLiveMapScreen({super.key, required this.configId});
  final String configId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionProvider(configId));
    final configsAsync = ref.watch(familiarConfigsProvider);

    final elderName = configsAsync.value
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
          final coords = _roundedCoords(session.lat, session.lng);

          return Column(
            children: [
              Expanded(
                child: FlutterMap(
                  options: MapOptions(initialCenter: point, initialZoom: 16),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.blackvikings.geoping',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 80,
                          height: 80,
                          child: Column(
                            children: [
                              const Icon(Icons.location_pin,
                                  color: AppTheme.colorBotonAbuelo, size: 48),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withAlpha(40),
                                        blurRadius: 4),
                                  ],
                                ),
                                child: Text(elderName,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _AddressPanel(
                lat: session.lat,
                lng: session.lng,
                coords: coords,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AddressPanel extends ConsumerWidget {
  const _AddressPanel({
    required this.lat,
    required this.lng,
    required this.coords,
  });

  final double lat;
  final double lng;
  final (double, double) coords;

  String get _mapsUrl =>
      'https://maps.google.com/?q=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';

  String get _coordsText =>
      '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copiado'), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressAsync = ref.watch(_addressProvider(coords));

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Dirección ──────────────────────────────────────────────────────
          addressAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Text('Obteniendo dirección…',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ]),
            ),
            error: (_, __) => _CopyRow(
              icon: Icons.location_on,
              text: _coordsText,
              onCopy: () => _copy(context, _coordsText, 'Dirección'),
            ),
            data: (addr) => _AddressBlock(addr: addr, onCopy: () {
              _copy(context, addr.display.isNotEmpty ? addr.display : _coordsText, 'Dirección');
            }),
          ),

          const Divider(height: 20),

          // ── Coordenadas ────────────────────────────────────────────────────
          _CopyRow(
            icon: Icons.my_location,
            text: _coordsText,
            onCopy: () => _copy(context, _coordsText, 'Coordenadas'),
          ),

          const SizedBox(height: 12),

          // ── Acciones ───────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copy(context, _mapsUrl, 'Enlace'),
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('Copiar enlace'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => launchUrl(Uri.parse(_mapsUrl)),
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text('Abrir en Maps'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddressBlock extends StatelessWidget {
  const _AddressBlock({required this.addr, required this.onCopy});
  final _GeoAddress addr;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.location_on, size: 20, color: Colors.grey),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (addr.streetLine.isNotEmpty) ...[
                Text(addr.streetLine,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
              ],
              if (addr.localityLine.isNotEmpty) ...[
                Text(addr.localityLine,
                    style: const TextStyle(fontSize: 13, color: Colors.black87)),
                const SizedBox(height: 2),
              ],
              if (addr.cityLine.isNotEmpty)
                Text(addr.cityLine,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              if (addr.streetLine.isEmpty && addr.display.isNotEmpty)
                Text(addr.display,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 20),
          tooltip: 'Copiar dirección',
          onPressed: onCopy,
        ),
      ],
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.icon, required this.text, required this.onCopy});
  final IconData icon;
  final String text;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          tooltip: 'Copiar',
          onPressed: onCopy,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ],
    );
  }
}
