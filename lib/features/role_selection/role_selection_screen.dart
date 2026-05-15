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
    if (role == UserRole.familiar) {
      ref.read(roleProvider.notifier).setRole(role);
      context.go('/familiar');
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
      ref.read(roleProvider.notifier).setRole(role);
      if (!mounted) return;
      context.go('/pingo');
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
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
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
                S.rolSeleccionSubtitulo,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 56),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                _RoleOptionCard(
                  icon: Icons.person_rounded,
                  title: S.rolPingo,
                  subtitle: 'Comparte tu ubicación con un solo toque',
                  color: AppTheme.colorBotonAbuelo,
                  onTap: () => _selectRole(UserRole.pingo),
                ),
                const SizedBox(height: 16),
                _RoleOptionCard(
                  icon: Icons.family_restroom_rounded,
                  title: S.rolFamiliar,
                  subtitle: 'Monitorea la ubicación de tus seres queridos',
                  color: Theme.of(context).colorScheme.secondary,
                  onTap: () => _selectRole(UserRole.familiar),
                  tonal: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleOptionCard extends StatelessWidget {
  const _RoleOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.tonal = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final bg = tonal ? color.withAlpha(18) : color;
    final fg = tonal ? color : Colors.white;
    final subtitleColor = tonal ? color.withAlpha(180) : Colors.white.withAlpha(210);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: fg.withAlpha(30),
        highlightColor: fg.withAlpha(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: fg.withAlpha(tonal ? 40 : 50),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: fg, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: subtitleColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, color: fg.withAlpha(150), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
