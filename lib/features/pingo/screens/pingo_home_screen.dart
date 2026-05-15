import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/models/pingo_pairing.dart';
import '../../../core/models/user_role.dart';
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
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.push('/pingo/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: pairings.isEmpty
            ? _EmptyState(onScan: () => context.push('/pingo/pair'))
            : _PairingList(pairings: pairings),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends ConsumerStatefulWidget {
  const _EmptyState({required this.onScan});
  final VoidCallback onScan;

  @override
  ConsumerState<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends ConsumerState<_EmptyState> {
  bool _signingIn = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _signingIn = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      ref.read(roleProvider.notifier).setRole(UserRole.pingo);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar sesión: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAnonymous =
        ref.watch(authProvider).value?.isAnonymous ?? true;

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
            child: const Icon(Icons.qr_code_scanner_rounded,
                size: 40, color: Colors.grey),
          ),
          const SizedBox(height: 20),
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
            onPressed: widget.onScan,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text(S.escanearQr),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(64),
              textStyle:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          if (isAnonymous) ...[
            const SizedBox(height: 16),
            _signingIn
                ? const Center(child: CircularProgressIndicator())
                : OutlinedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Recuperar mis configuraciones'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List of pairings — one card per familiar
// ---------------------------------------------------------------------------

class _PairingList extends ConsumerWidget {
  const _PairingList({required this.pairings});
  final List<PingoPairing> pairings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '¿A quién quieres avisar?',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.grey[700]),
          ),
          const SizedBox(height: 24),
          ...pairings.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _FamiliarCard(pairing: p),
              )),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/pingo/pair'),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text(S.escanearQr),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// State switcher
// ---------------------------------------------------------------------------

class _FamiliarCard extends ConsumerWidget {
  const _FamiliarCard({required this.pairing});
  final PingoPairing pairing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionNotifierProvider(pairing.configId));

    return sessionState.map(
      idle: (_) => _IdleCard(
        familiarName: pairing.familiarName,
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
// State: idle — big send button
// ---------------------------------------------------------------------------

class _IdleCard extends StatelessWidget {
  const _IdleCard({required this.familiarName, required this.onPressed});
  final String familiarName;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final initial = familiarName.isNotEmpty
        ? familiarName[0].toUpperCase()
        : '?';
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        familiarName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Tu familiar',
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
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.location_on_rounded, size: 24),
              label: const Text(S.avisarUbicacion),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.colorBotonAbuelo,
                minimumSize: const Size.fromHeight(72),
                textStyle:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// State: starting — loading
// ---------------------------------------------------------------------------

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppTheme.colorBotonAbuelo,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Avisando a $name…',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Compartiendo tu ubicación',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// State: active — session running, auto-refreshes every 30s
// ---------------------------------------------------------------------------

class _ActiveCard extends StatefulWidget {
  const _ActiveCard({
    required this.familiarName,
    required this.expiresAt,
    required this.onStop,
  });
  final String familiarName;
  final DateTime expiresAt;
  final VoidCallback onStop;

  @override
  State<_ActiveCard> createState() => _ActiveCardState();
}

class _ActiveCardState extends State<_ActiveCard> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.expiresAt.difference(DateTime.now());
    final minutes = remaining.inMinutes.clamp(0, 120);
    final initial = widget.familiarName.isNotEmpty
        ? widget.familiarName[0].toUpperCase()
        : '?';

    return Card(
      color: AppTheme.colorSesionActiva.withAlpha(12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: AppTheme.colorSesionActiva, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status badge
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppTheme.colorSesionActiva,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'SESIÓN ACTIVA',
                  style: TextStyle(
                    color: AppTheme.colorSesionActiva,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.colorSesionActiva.withAlpha(22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$minutes ${S.minRestantes}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.colorSesionActiva,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Familiar info
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.colorSesionActiva.withAlpha(28),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.colorSesionActiva,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.familiarName,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'puede ver tu ubicación',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Stop button
            OutlinedButton.icon(
              onPressed: widget.onStop,
              icon: const Icon(Icons.stop_circle_rounded,
                  color: AppTheme.colorDanger, size: 20),
              label: const Text(
                S.detenerSesion,
                style: TextStyle(
                    color: AppTheme.colorDanger, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.colorDanger),
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// State: error
// ---------------------------------------------------------------------------

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
      color: AppTheme.colorDangerSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.colorDanger.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppTheme.colorDanger, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error al avisar a $familiarName',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.colorDanger,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text(S.reintentar),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.colorBotonAbuelo,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
