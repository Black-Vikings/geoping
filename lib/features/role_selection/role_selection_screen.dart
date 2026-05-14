import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user_role.dart';
import '../../core/providers.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  bool _loading = false;

  Future<void> _selectRole(UserRole role) async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
      await ref.read(roleProvider.notifier).setRole(role);
      if (!mounted) return;
      context.go(role == UserRole.pingo ? '/pingo' : '/familiar');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${S.errorConexion}: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.location_on, size: 80, color: AppTheme.colorBotonAbuelo),
              const SizedBox(height: 24),
              Text(
                S.appName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 8),
              Text(
                S.rolSeleccionSubtitulo,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 64),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                FilledButton.icon(
                  onPressed: () => _selectRole(UserRole.pingo),
                  icon: const Icon(Icons.person, size: 28),
                  label: const Text(S.rolPingo),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.colorBotonAbuelo,
                    minimumSize: const Size.fromHeight(72),
                    textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => _selectRole(UserRole.familiar),
                  child: const Text(S.rolFamiliar),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(72),
                    textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
