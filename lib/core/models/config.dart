import 'package:freezed_annotation/freezed_annotation.dart';

part 'config.freezed.dart';
part 'config.g.dart';

@freezed
class Config with _$Config {
  const factory Config({
    required String id,
    required String elderName,
    // The familiar's own display name — shown on the Pingo's button
    required String familiarName,
    required List<Contact> contacts,
    required String ownerUid,
    required String writeToken,
    @Default([]) List<String> fcmTokens,
    DateTime? createdAt,
  }) = _Config;

  factory Config.fromJson(Map<String, dynamic> json) => _$ConfigFromJson(json);
}

@freezed
class Contact with _$Contact {
  const factory Contact({
    required String name,
    required String phone,
  }) = _Contact;

  factory Contact.fromJson(Map<String, dynamic> json) =>
      _$ContactFromJson(json);
}
