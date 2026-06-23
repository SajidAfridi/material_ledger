import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Salted SHA-256 password hashing for the **local** auth stand-in.
///
/// This is a throwaway local mechanism so the prototype has real credential
/// checking before Firebase. When Firebase Auth lands it owns authentication
/// entirely (passwords live as hashed Auth credentials, never in app data), and
/// these fields are simply dropped from the Firestore mapping — see
/// [AuthService]. Do not treat this as production-grade KDF.
abstract final class PasswordHasher {
  static final Random _rng = Random.secure();

  /// A fresh random salt (base64, 16 bytes).
  static String newSalt() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Hash [password] with [salt] → hex digest of sha256(salt + password).
  static String hash(String password, String salt) {
    return sha256.convert(utf8.encode('$salt$password')).toString();
  }

  /// Create a `(hash, salt)` pair for a new/changed password.
  static ({String hash, String salt}) create(String password) {
    final salt = newSalt();
    return (hash: hash(password, salt), salt: salt);
  }

  /// Constant-ish verification of [password] against a stored [hash]/[salt].
  static bool verify(String password, String hash, String salt) {
    if (hash.isEmpty || salt.isEmpty) return false;
    return PasswordHasher.hash(password, salt) == hash;
  }
}
