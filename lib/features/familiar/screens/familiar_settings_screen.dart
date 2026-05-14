import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/strings.dart';

class FamiliarSettingsScreen extends ConsumerWidget {
  const FamiliarSettingsScreen({super.key, required this.configId});
  final String configId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync = ref.watch(familiarConfigsProvider);
    final config = configsAsync.valueOrNull
        ?.where((c) => c.id == configId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text(S.configuracion)),
      body: config == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(config.elderName,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('ID: ${config.id}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const Divider(height: 32),
                if (config.contacts.isNotEmpty) ...[
                  Text(S.agregarContacto,
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  ...config.contacts.map((c) => ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(c.name, style: const TextStyle(fontSize: 16)),
                        subtitle: Text(c.phone),
                      )),
                  const Divider(height: 32),
                ],
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(S.restablecerConfig,
                      style: TextStyle(color: Colors.red, fontSize: 16)),
                  onTap: () => _confirmDelete(context, ref),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.swap_horiz),
                  title:
                      const Text(S.cerrarSesion, style: TextStyle(fontSize: 16)),
                  onTap: () async {
                    await ref.read(roleProvider.notifier).clearRole();
                    if (context.mounted) context.go('/role');
                  },
                ),
              ],
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(S.restablecerConfig),
        content: const Text(S.restablecerConfirmacion),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(S.cancelar)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text(S.confirmar, style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance.doc('configs/$configId').delete();
      if (context.mounted) context.pop();
    }
  }
}
