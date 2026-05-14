import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/config.dart';
import '../../../core/strings.dart';

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
  final _contactNameController = TextEditingController();
  String _contactPhone = '';
  final List<Contact> _contacts = [];
  bool _saving = false;

  @override
  void dispose() {
    _elderNameController.dispose();
    _familiarNameController.dispose();
    _contactNameController.dispose();
    super.dispose();
  }

  void _addContact() {
    final name = _contactNameController.text.trim();
    if (name.isEmpty || _contactPhone.isEmpty) return;
    setState(() {
      _contacts.add(Contact(name: name, phone: _contactPhone));
      _contactNameController.clear();
      _contactPhone = '';
    });
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
        contacts: _contacts,
        ownerUid: uid,
        writeToken: writeToken,
        fcmTokens: const [],
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
          padding: const EdgeInsets.all(24),
          children: [
            // Tu nombre (aparecerá en los botones del Pingo)
            TextFormField(
              controller: _familiarNameController,
              decoration: InputDecoration(
                labelText: S.tuNombreHint,
                helperText: S.tuNombreHelper,
                border: const OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 18),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? S.error : null,
            ),
            const SizedBox(height: 20),

            // Nombre del Pingo
            TextFormField(
              controller: _elderNameController,
              decoration: const InputDecoration(
                labelText: S.nombrePingoHint,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 18),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? S.error : null,
            ),
            const SizedBox(height: 32),

            Text(S.agregarContacto,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              S.contactosHelper,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactNameController,
              decoration: const InputDecoration(
                labelText: S.nombreContacto,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            IntlPhoneField(
              decoration: const InputDecoration(
                labelText: S.telefonoContacto,
                border: OutlineInputBorder(),
              ),
              initialCountryCode: 'MX',
              style: const TextStyle(fontSize: 18),
              onChanged: (phone) => _contactPhone = phone.completeNumber,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addContact,
              icon: const Icon(Icons.add),
              label: const Text(S.agregarContacto),
            ),
            if (_contacts.isNotEmpty) ...[
              const SizedBox(height: 16),
              ..._contacts.map((c) => ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(c.name, style: const TextStyle(fontSize: 16)),
                    subtitle: Text(c.phone),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => setState(() => _contacts.remove(c)),
                    ),
                  )),
            ],
            const SizedBox(height: 40),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(S.guardar),
            ),
          ],
        ),
      ),
    );
  }
}
