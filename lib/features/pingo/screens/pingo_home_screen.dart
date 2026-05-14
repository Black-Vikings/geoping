import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/pingo_pairing.dart';
import '../../../core/providers.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../state/session_notifier.dart';
import '../state/session_state.dart';

class PingoHomeScreen extends ConsumerWidget {
  const PingoHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairings = ref.watch(pingoConfigsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/pingo/settings'),
          ),
        ],
      ),
      body: pairings.isEmpty
          ? _EmptyState(onScan: () => context.push('/pingo/pair'))
          : _PairingList(pairings: pairings),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onScan});
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.qr_code_scanner, size: 80, color: Colors.grey),
          const SizedBox(height: 24),
          Text(
            S.pingoSinConfig,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            S.pingoSinConfigDesc,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 40),
          FilledButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text(S.escanearQr),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List of pairings — one card/button per familiar
// ---------------------------------------------------------------------------

class _PairingList extends ConsumerWidget {
  const _PairingList({required this.pairings});
  final List<PingoPairing> pairings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '¿A quién quieres avisar?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 32),
          ...pairings.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _FamiliarButton(pairing: p),
              )),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.push('/pingo/pair'),
            icon: const Icon(Icons.add),
            label: const Text(S.escanearQr),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One button per familiar — shows active/idle state inline
// ---------------------------------------------------------------------------

class _FamiliarButton extends ConsumerWidget {
  const _FamiliarButton({required this.pairing});
  final PingoPairing pairing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionNotifierProvider(pairing.configId));

    return sessionState.map(
      idle: (_) => _SendButton(
        label: '${S.avisarUbicacion}\na ${pairing.familiarName}',
        onPressed: () => ref
            .read(sessionNotifierProvider(pairing.configId).notifier)
            .startSession(pairing.writeToken),
      ),
      starting: (_) => _LoadingCard(name: pairing.familiarName),
      active: (s) => _ActiveCard(
        familiarName: pairing.familiarName,
        expiresAt: s.expiresAt,
        onStop: () => ref
            .read(sessionNotifierProvider(pairing.configId).notifier)
            .stopSession(),
      ),
      error: (e) => _ErrorCard(
        familiarName: pairing.familiarName,
        message: e.message,
        onRetry: () => ref
            .read(sessionNotifierProvider(pairing.configId).notifier)
            .startSession(pairing.writeToken),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SendButton extends StatelessWidget {
  const _SendButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.colorBotonAbuelo,
        minimumSize: const Size.fromHeight(88),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text('Conectando con $name…',
                style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({
    required this.familiarName,
    required this.expiresAt,
    required this.onStop,
  });
  final String familiarName;
  final DateTime expiresAt;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final minutes =
        expiresAt.difference(DateTime.now()).inMinutes.clamp(0, 60);

    return Card(
      color: AppTheme.colorSesionActiva.withAlpha(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.colorSesionActiva, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on,
                    color: AppTheme.colorSesionActiva, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.sesionActiva,
                    style: const TextStyle(
                      color: AppTheme.colorSesionActiva,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${S.visiblePara} $familiarName · $minutes ${S.minRestantes}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onStop,
              icon: const Icon(Icons.stop_circle, color: Colors.red),
              label: const Text(S.detenerSesion,
                  style: TextStyle(color: Colors.red, fontSize: 16)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.familiarName,
    required this.message,
    required this.onRetry,
  });
  final String familiarName;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Error al enviar a $familiarName',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red),
            ),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(fontSize: 14, color: Colors.red)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text(S.reintentar),
            ),
          ],
        ),
      ),
    );
  }
}
