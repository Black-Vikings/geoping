import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/models/pingo_pairing.dart';
import '../../../core/providers.dart';
import '../../../core/strings.dart';

class PingoPairScreen extends ConsumerStatefulWidget {
  const PingoPairScreen({super.key});

  @override
  ConsumerState<PingoPairScreen> createState() => _PingoPairScreenState();
}

class _PingoPairScreenState extends ConsumerState<PingoPairScreen> {
  bool _processed = false;
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processed) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final payload = QrPayload.fromJson(json);
      if (payload.v != 1) throw Exception('Versión inválida');

      final displayName =
          (payload.familiarName?.isNotEmpty == true
                  ? payload.familiarName
                  : payload.elderName) ??
              'Familiar';

      _processed = true;
      _controller.stop();

      final pairing = PingoPairing(
        configId: payload.configId,
        writeToken: payload.writeToken,
        familiarName: displayName,
      );

      ref.read(pingoConfigsProvider.notifier).addPairing(pairing);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${S.escaneoExitoso} — $displayName')),
      );
      context.pop();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(S.qrInvalido)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.escanearQr)),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
      ),
    );
  }
}
