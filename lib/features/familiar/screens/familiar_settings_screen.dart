import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';

class FamiliarSettingsScreen extends ConsumerWidget {
  const FamiliarSettingsScreen({super.key, required this.configId});
  final String configId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync = ref.watch(familiarConfigsProvider);
    final config =
        configsAsync.value?.where((c) => c.id == configId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text(S.configuracion)),
      body: config == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.colorBotonAbuelo.withAlpha(18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppTheme.colorBotonAbuelo,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            config.elderName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Familiar: ${config.familiarName}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'ID: ${config.id}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 36),
                _DangerZone(onDelete: () => _confirmDelete(context, ref)),
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
              child: Text(S.confirmar,
                  style: const TextStyle(color: AppTheme.colorDanger))),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance.doc('configs/$configId').delete();
      if (context.mounted) context.pop();
    }
  }
}

class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.onDelete});
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            leading:
                const Icon(Icons.delete_rounded, color: AppTheme.colorDanger),
            title: Text(
              S.restablecerConfig,
              style: const TextStyle(
                  color: AppTheme.colorDanger, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Esta acción no se puede deshacer',
                style: TextStyle(fontSize: 13)),
            onTap: onDelete,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
