import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/providers.dart';
import '../../../core/strings.dart';

class FamiliarQrScreen extends ConsumerWidget {
  const FamiliarQrScreen({super.key, required this.configId});
  final String configId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync = ref.watch(familiarConfigsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(S.generarQr)),
      body: configsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${S.errorConexion}: $e')),
        data: (configs) {
          final config = configs.where((c) => c.id == configId).firstOrNull;
          if (config == null) return const Center(child: Text(S.error));

          // familiarName goes in the QR so the Pingo's button shows "Enviar a [familiarName]"
          final payload = jsonEncode({
            'v': 1,
            'configId': config.id,
            'writeToken': config.writeToken,
            'familiarName': config.familiarName,
          });

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${S.generarQr} · ${config.familiarName}',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Para: ${config.elderName}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 12,
                        )
                      ],
                    ),
                    child: QrImageView(
                      data: payload,
                      version: QrVersions.auto,
                      size: 260,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${config.elderName} debe escanear este código con la app GeoPing',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
