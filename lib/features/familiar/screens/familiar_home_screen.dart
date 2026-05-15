import 'package:firebase_auth/firebase_auth.dart';
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
    final userAsync = ref.watch(authProvider);
    final configsAsync = ref.watch(familiarConfigsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.misPingosTitle),
        actions: [
          userAsync.value != null
              ? Row(
                  children: [
                    if (userAsync.value!.photoURL != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundImage:
                              NetworkImage(userAsync.value!.photoURL!),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded),
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      tooltip: 'Cerrar sesión',
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_add_rounded),
                      onPressed: () => context.push('/new'),
                      tooltip: S.agregarPingo,
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(message: '${S.errorConexion}: $e'),
        data: (user) {
          if (user == null) return const _SignInPrompt();
          return configsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorBody(message: '${S.errorConexion}: $e'),
            data: (configs) => configs.isEmpty
                ? _EmptyState(onAdd: () => context.push('/new'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    itemCount: configs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _ConfigCard(config: configs[i]),
                  ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Colors.grey[600]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SignInPrompt extends StatefulWidget {
  const _SignInPrompt();

  @override
  State<_SignInPrompt> createState() => _SignInPromptState();
}

class _SignInPromptState extends State<_SignInPrompt> {
  bool _loading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar sesión: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.colorBotonAbuelo.withAlpha(18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_rounded,
              size: 44,
              color: AppTheme.colorBotonAbuelo,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            S.appName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Inicia sesión para gestionar tus Pingos',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 40),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : FilledButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Continuar con Google'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
                ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_rounded, size: 44, color: Colors.grey),
          ),
          const SizedBox(height: 20),
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
            icon: const Icon(Icons.add_rounded),
            label: const Text(S.agregarPingo),
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ConfigCard extends ConsumerWidget {
  const _ConfigCard({required this.config});
  final Config config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionProvider(config.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
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
                  icon: const Icon(Icons.qr_code_rounded),
                  onPressed: () => context.push('/${config.id}/qr'),
                  tooltip: S.generarQr,
                ),
                IconButton(
                  icon: const Icon(Icons.settings_rounded),
                  onPressed: () => context.push('/${config.id}/settings'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            sessionAsync.when(
              loading: () => const SizedBox(
                height: 3,
                child: LinearProgressIndicator(),
              ),
              error: (_, __) => Text(
                S.errorConexion,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.red),
              ),
              data: (session) {
                final isActive = session?.active == true;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatusChip(isActive: isActive),
                    if (isActive) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => context.push('/${config.id}/map'),
                        icon: const Icon(Icons.map_rounded, size: 18),
                        label: const Text(S.verMapa),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.colorSesionActiva,
                          minimumSize: const Size.fromHeight(44),
                          textStyle: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.colorSesionActiva.withAlpha(20)
                : Colors.grey.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.colorSesionActiva
                      : AppTheme.colorSesionInactiva,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isActive ? S.sesionActiva : S.sinSesion,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? AppTheme.colorSesionActiva
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
