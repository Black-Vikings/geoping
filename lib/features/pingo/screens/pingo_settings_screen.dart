import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
    final userAsync = ref.watch(authProvider);
    final user = userAsync.value;
    final isAnonymous = user?.isAnonymous ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text(S.configuracion)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Cuenta ──────────────────────────────────────────────────────────
          _SectionLabel(label: 'Cuenta'),
          const SizedBox(height: 10),
          isAnonymous
              ? _LinkGoogleCard(onLink: () => _linkGoogle(context, ref))
              : _GoogleAccountCard(
                  user: user!,
                  onSignOut: () => _signOut(context),
                ),
          const SizedBox(height: 32),

          // ── Familiares conectados ────────────────────────────────────────────
          if (pairings.isNotEmpty) ...[
            _SectionLabel(label: 'Familiares conectados'),
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
                          color:
                              Theme.of(context).colorScheme.primaryContainer,
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
                        onPressed: () =>
                            _confirmDelete(context, ref, pairings[i].configId),
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

          if (pairings.isEmpty && isAnonymous) _EmptySettings(),

          // ── Zona peligrosa ─────────────────────────────────────────────────
          if (pairings.isNotEmpty) ...[
            _SectionLabel(label: 'Zona peligrosa'),
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

  Future<void> _linkGoogle(BuildContext context, WidgetRef ref) async {
    final localPairings = ref.read(pingoConfigsProvider);
    try {
      final UserCredential cred;
      if (kIsWeb) {
        cred = await FirebaseAuth.instance.currentUser!
            .linkWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        cred = await FirebaseAuth.instance.currentUser!
            .linkWithCredential(credential);
      }
      await ref
          .read(pingoConfigsProvider.notifier)
          .migrateLocalToFirestore(cred.user!.uid, localPairings);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('¡Cuenta vinculada! Tus datos están a salvo.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al vincular: $e')),
        );
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) context.go('/');
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

// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[500],
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
    );
  }
}

class _LinkGoogleCard extends StatelessWidget {
  const _LinkGoogleCard({required this.onLink});
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x1A000000)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.blue.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.account_circle_rounded,
              size: 22, color: Colors.blue),
        ),
        title: const Text('Vincular con Google',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: const Text(
          'Guarda tus conexiones en la nube',
          style: TextStyle(fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: onLink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _GoogleAccountCard extends StatelessWidget {
  const _GoogleAccountCard({required this.user, required this.onSignOut});
  final User user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x1A000000)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: user.photoURL != null
                ? CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(user.photoURL!),
                  )
                : Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_circle_rounded,
                        size: 22, color: Colors.green),
                  ),
            title: Text(
              user.displayName ?? 'Google',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              user.email ?? '',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Sincronizado',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600)),
            ),
            shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(12))),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppTheme.colorDanger),
            title: const Text('Cerrar sesión',
                style: TextStyle(
                    color: AppTheme.colorDanger, fontWeight: FontWeight.w600)),
            onTap: onSignOut,
            shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(12))),
          ),
        ],
      ),
    );
  }
}

class _EmptySettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
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
