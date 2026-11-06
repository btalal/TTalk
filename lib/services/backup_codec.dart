import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../crypto/e2e_crypto.dart';

/// Portable authenticated backup, with an independent salt and password key.
/// Bounds are fixed before expensive KDF/decode work; secrets never leave the
/// device except inside this encrypted file explicitly saved by the user.
class BackupCodec {
  static const maxBytes = 32 * 1024 * 1024;
  static const iterations = 600000;
  static void validatePassword(String value) {
    if (value.length < 16 || value.length > 256) {
      throw ArgumentError(
        'Choisis une phrase de passe de 16 à 256 caractères.',
      );
    }
  }

  static Future<SecretKey> _key(String pass, List<int> salt) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(pass)), nonce: salt);
  static Future<Uint8List> encode(
    Map<String, dynamic> data,
    String password,
  ) async {
    validatePassword(password);
    final plain = Uint8List.fromList(utf8.encode(jsonEncode(data)));
    if (plain.length > maxBytes ~/ 2) {
      throw StateError(
        'Sauvegarde trop volumineuse (16 Mo maximum avant chiffrement).',
      );
    }
    final salt = randomBytes(32);
    final encrypted = await encryptLocal(await _key(password, salt), plain);
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'ttalk.backup.v1',
          'kdf': 'pbkdf2-sha256-600000',
          'salt': base64Encode(salt),
          'ciphertext': base64Encode(encrypted),
        }),
      ),
    );
  }

  static Future<Map<String, dynamic>> decode(
    Uint8List bytes,
    String password,
  ) async {
    validatePassword(password);
    if (bytes.length > maxBytes) {
      throw const FormatException('Sauvegarde trop volumineuse.');
    }
    final outer = jsonDecode(utf8.decode(bytes));
    if (outer is! Map ||
        outer['format'] != 'ttalk.backup.v1' ||
        outer['kdf'] != 'pbkdf2-sha256-600000' ||
        outer['salt'] is! String ||
        outer['ciphertext'] is! String ||
        (outer['salt'] as String).length > 48) {
      throw const FormatException('Format de sauvegarde invalide.');
    }
    final salt = base64Decode(outer['salt'] as String);
    if (salt.length != 32) throw const FormatException('Sel invalide.');
    final clear = await decryptLocal(
      await _key(password, salt),
      base64Decode(outer['ciphertext'] as String),
    );
    final data = jsonDecode(utf8.decode(clear));
    if (data is! Map<String, dynamic> || data['version'] != 1) {
      throw const FormatException('Contenu de sauvegarde invalide.');
    }
    return data;
  }
}
