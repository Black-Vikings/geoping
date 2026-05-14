import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/strings.dart';

class PingoSettingsScreen extends ConsumerWidget {
  const PingoSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairings = ref.watch(pingoConfigsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(S.configuracion)),
      body: Column(
        children: [
          if (pairings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(S.pingoSinConfig, style: TextStyle(fontSize: 16)),
            )
          else
            ...pairings.map((p) => ListTile(
                  leading: const Icon(Icons.person),
                  title:
                      Text(p.familiarName, style: const TextStyle(fontSize: 18)),
                  subtitle: Text(p.configId, style: const TextStyle(fontSize: 14)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(context, ref, p.configId),
                  ),
                )),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text(S.cerrarSesion, style: TextStyle(fontSize: 18)),
            onTap: () async {
              await ref.read(roleProvider.notifier).clearRole();
              if (context.mounted) context.go('/role');
            },
          ),
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
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(pingoConfigsProvider.notifier).removePairing(configId);
    }
  }
}
