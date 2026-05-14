import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/config.dart';
import '../../../core/providers.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';

class FamiliarHomeScreen extends ConsumerWidget {
  const FamiliarHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync = ref.watch(familiarConfigsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.misPingosTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => context.push('/familiar/new'),
            tooltip: S.agregarPingo,
          ),
        ],
      ),
      body: configsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('${S.errorConexion}: $e', style: const TextStyle(fontSize: 16)),
        ),
        data: (configs) => configs.isEmpty
            ? _EmptyState(onAdd: () => context.push('/familiar/new'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: configs.length,
                itemBuilder: (_, i) => _ConfigCard(config: configs[i]),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.people, size: 80, color: Colors.grey),
          const SizedBox(height: 24),
          Text(
            S.sinPingosDesc,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 40),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text(S.agregarPingo),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
          ),
        ],
      ),
    );
  }
}

class _ConfigCard extends ConsumerWidget {
  const _ConfigCard({required this.config});
  final Config config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionProvider(config.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    config.elderName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code),
                  onPressed: () => context.push('/familiar/${config.id}/qr'),
                  tooltip: S.generarQr,
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () =>
                      context.push('/familiar/${config.id}/settings'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            sessionAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) =>
                  const Text(S.errorConexion, style: TextStyle(fontSize: 16)),
              data: (session) {
                final isActive = session?.active == true;
                return Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 12,
                      color: isActive
                          ? AppTheme.colorSesionActiva
                          : AppTheme.colorSesionInactiva,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isActive ? S.sesionActiva : S.sinSesion,
                      style: TextStyle(
                        fontSize: 16,
                        color: isActive
                            ? AppTheme.colorSesionActiva
                            : Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    if (isActive)
                      FilledButton.icon(
                        onPressed: () =>
                            context.push('/familiar/${config.id}/map'),
                        icon: const Icon(Icons.map),
                        label: const Text(S.verMapa),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.colorSesionActiva,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
