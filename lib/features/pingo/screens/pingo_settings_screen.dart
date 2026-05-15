import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';

class PingoSettingsScreen extends ConsumerWidget {
  const PingoSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairings = ref.watch(pingoConfigsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(S.configuracion)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (pairings.isEmpty)
            _EmptySettings()
          else ...[
            Text(
              'Familiares conectados',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0x1A000000)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < pairings.length; i++) ...[
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          size: 20,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                      title: Text(pairings[i].familiarName,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600)),
                      subtitle: Text(pairings[i].configId,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppTheme.colorDanger),
                        onPressed: () => _confirmDelete(
                            context, ref, pairings[i].configId),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(i == 0 ? 12 : 0),
                          topRight: Radius.circular(i == 0 ? 12 : 0),
                          bottomLeft: Radius.circular(
                              i == pairings.length - 1 ? 12 : 0),
                          bottomRight: Radius.circular(
                              i == pairings.length - 1 ? 12 : 0),
                        ),
                      ),
                    ),
                    if (i < pairings.length - 1)
                      const Divider(height: 1, indent: 64),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
          if (pairings.isNotEmpty) ...[
            Text(
              'Zona peligrosa',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.colorDangerSurface,
                border: Border.all(color: AppTheme.colorDanger.withAlpha(50)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.delete_sweep_rounded,
                    color: AppTheme.colorDanger),
                title: Text(
                  S.restablecerConfig,
                  style: const TextStyle(
                      color: AppTheme.colorDanger,
                      fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Elimina todas las configuraciones',
                    style: TextStyle(fontSize: 13)),
                onTap: () async {
                  for (final p in pairings) {
                    ref
                        .read(pingoConfigsProvider.notifier)
                        .removePairing(p.configId);
                  }
                  if (context.mounted) context.pop();
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String configId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(S.restablecerConfig),
        content: const Text(S.restablecerConfirmacion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(S.cancelar),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(S.confirmar,
                style: TextStyle(color: AppTheme.colorDanger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(pingoConfigsProvider.notifier).removePairing(configId);
    }
  }
}

class _EmptySettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.settings_rounded,
                size: 32, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Text(
            S.pingoSinConfig,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            'Escanea un QR para conectarte con tu familiar',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
