import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Device-persistent idempotency leases for online-only workflow commands.
///
/// Only a SHA-256 payload fingerprint and opaque UUID are stored. Protected
/// commercial values, notes and workflow quantities never enter preferences.
/// A lease is cleared only after the repository returns a confirmed response;
/// timeouts and transport failures therefore retry with the same server key.
class YorksV1CriticalCommandKeyStore {
  YorksV1CriticalCommandKeyStore({
    required SharedPreferences preferences,
    required String actorAuthUserId,
    String Function() uuidFactory = _uuidV4,
  }) : _preferences = preferences,
       _actorAuthUserId = actorAuthUserId.trim(),
       _uuidFactory = uuidFactory;

  static const _prefix = 'yorks_v1_critical_command_key_v1';

  final SharedPreferences _preferences;
  final String _actorAuthUserId;
  final String Function() _uuidFactory;

  Future<String> acquire({
    required String operation,
    required String entityId,
    required Map<String, Object?> payload,
  }) async {
    final storageKey = _storageKey(operation, entityId);
    final fingerprint = sha256
        .convert(utf8.encode(jsonEncode(payload)))
        .toString();
    final existing = _decode(_preferences.getString(storageKey));
    if (existing != null && existing.fingerprint == fingerprint) {
      return existing.idempotencyKey;
    }
    final idempotencyKey = _uuidFactory();
    await _preferences.setString(
      storageKey,
      jsonEncode({
        'fingerprint': fingerprint,
        'idempotency_key': idempotencyKey,
      }),
    );
    return idempotencyKey;
  }

  Future<void> confirm({
    required String operation,
    required String entityId,
    required String idempotencyKey,
  }) async {
    final storageKey = _storageKey(operation, entityId);
    final existing = _decode(_preferences.getString(storageKey));
    if (existing?.idempotencyKey == idempotencyKey) {
      await _preferences.remove(storageKey);
    }
  }

  String _storageKey(String operation, String entityId) {
    final namespace = sha256
        .convert(
          utf8.encode(
            '$_actorAuthUserId:${operation.trim()}:${entityId.trim()}',
          ),
        )
        .toString();
    return '${_prefix}_$namespace';
  }

  static _StoredCommandKey? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final fingerprint = json['fingerprint'];
      final idempotencyKey = json['idempotency_key'];
      if (fingerprint is! String || idempotencyKey is! String) return null;
      return _StoredCommandKey(
        fingerprint: fingerprint,
        idempotencyKey: idempotencyKey,
      );
    } on FormatException {
      return null;
    }
  }
}

String _uuidV4() => const Uuid().v4();

class _StoredCommandKey {
  const _StoredCommandKey({
    required this.fingerprint,
    required this.idempotencyKey,
  });

  final String fingerprint;
  final String idempotencyKey;
}
