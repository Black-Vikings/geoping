import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_state.freezed.dart';

@freezed
sealed class SessionState with _$SessionState {
  const factory SessionState.idle() = SessionIdle;
  const factory SessionState.starting() = SessionStarting;
  const factory SessionState.active({
    required String configId,
    required DateTime expiresAt,
  }) = SessionActive;
  const factory SessionState.error(String message) = SessionError;
}
