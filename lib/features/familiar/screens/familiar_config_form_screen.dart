import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/config.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';

class FamiliarConfigFormScreen extends ConsumerStatefulWidget {
  const FamiliarConfigFormScreen({super.key});

  @override
  ConsumerState<FamiliarConfigFormScreen> createState() =>
      _FamiliarConfigFormScreenState();
}

class _FamiliarConfigFormScreenState
    extends ConsumerState<FamiliarConfigFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _elderNameController = TextEditingController();
  final _familiarNameController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _elderNameController.dispose();
    _familiarNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final configId = const Uuid().v4();
      final writeToken = const Uuid().v4();

      final config = Config(
        id: configId,
        elderName: _elderNameController.text.trim(),
        familiarName: _familiarNameController.text.trim(),
        ownerUid: uid,
        writeToken: writeToken,
        createdAt: DateTime.now(),
      );

      final data = config.toJson()
        ..remove('id')
        ..['createdAt'] = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance.doc('configs/$configId').set(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(S.configuracionGuardada)),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${S.errorConexion}: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.agregarPingo)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppTheme.colorBotonAbuelo.withAlpha(18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_rounded,
                  size: 34,
                  color: AppTheme.colorBotonAbuelo,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Nuevo Pingo',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Completa los datos para conectar al Pingo',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _familiarNameController,
              decoration: InputDecoration(
                labelText: S.tuNombreHint,
                helperText: S.tuNombreHelper,
                prefixIcon: const Icon(Icons.badge_rounded),
              ),
              style: const TextStyle(fontSize: 17),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? S.error : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _elderNameController,
              decoration: const InputDecoration(
                labelText: S.nombrePingoHint,
                prefixIcon: Icon(Icons.person_rounded),
              ),
              style: const TextStyle(fontSize: 17),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? S.error : null,
            ),
            const SizedBox(height: 40),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(S.guardar),
            ),
          ],
        ),
      ),
    );
  }
}
