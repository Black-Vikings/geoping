import 'package:freezed_annotation/freezed_annotation.dart';

part 'pingo_pairing.freezed.dart';
part 'pingo_pairing.g.dart';

@freezed
abstract class PingoPairing with _$PingoPairing {
  const factory PingoPairing({
    required String configId,
    required String writeToken,
    required String familiarName,
  }) = _PingoPairing;

  factory PingoPairing.fromJson(Map<String, dynamic> json) =>
      _$PingoPairingFromJson(json);
}

@freezed
abstract class QrPayload with _$QrPayload {
  const factory QrPayload({
    required int v,
    required String configId,
    required String writeToken,
    String? familiarName,
    String? elderName,
  }) = _QrPayload;

  factory QrPayload.fromJson(Map<String, dynamic> json) =>
      _$QrPayloadFromJson(json);
}
