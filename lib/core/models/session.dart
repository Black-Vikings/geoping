import 'package:freezed_annotation/freezed_annotation.dart';

part 'session.freezed.dart';
part 'session.g.dart';

@freezed
abstract class Session with _$Session {
  const factory Session({
    required bool active,
    required double lat,
    required double lng,
    required double accuracy,
    required String writeToken,
    DateTime? updatedAt,
    DateTime? expiresAt,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) =>
      _$SessionFromJson(json);
}
