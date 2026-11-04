import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:convert/convert.dart' as convert;
import 'package:crypto/crypto.dart' as crypto_pkg;
import 'package:cryptography/cryptography.dart';

const int aesKeyLength = 32;
const int gcmNonceLength = 12;
const int saltLength = 16;
const int pbkdf2Iterations = 210000;

Uint8List randomBytes(int length) {
  final rng = Random.secure();
  return Uint8List.fromList(
      List<int>.generate(length, (_) => rng.nextInt(256)));
}

class IdentityKeys {
  IdentityKeys({required this.publicKey, required this.privateKey});

  final SimpleKeyPair privateKey;
  final Uint8List publicKey;

  static Future<IdentityKeys> generate() async {
    final kp = await X25519().newKeyPair();
    final pub = await kp.extractPublicKey();
    return IdentityKeys(
        privateKey: kp, publicKey: Uint8List.fromList(pub.bytes));
  }

  Future<SecretKey> deriveSessionKey(Uint8List remotePublicKey) async {
    final remote = SimplePublicKey(remotePublicKey, type: KeyPairType.x25519);
    final shared = await X25519().sharedSecretKey(
      keyPair: privateKey,
      remotePublicKey: remote,
    );
    final hkdf = Hkdf(hmac: Hmac(Sha256()), outputLength: aesKeyLength);
    return hkdf.deriveKey(
      secretKey: shared,
      nonce: utf8.encode('ttalk-session-v1'),
    );
  }
}

final _aes256 = AesGcm.with256bits();

Future<Uint8List> _encryptBytes(SecretKey key, List<int> plaintext) async {
  final nonce = randomBytes(gcmNonceLength);
  final box = await _aes256.encrypt(plaintext, secretKey: key, nonce: nonce);
  final out = BytesBuilder(copy: false)
    ..add(nonce)
    ..add(box.concatenation());
  return out.toBytes();
}

Future<Uint8List> _decryptBytes(SecretKey key, Uint8List payload) async {
  if (payload.length < gcmNonceLength * 2 + 16) {
    throw const FormatException('Paquet chiffré trop court');
  }
  // The v1 format includes a nonce prefix followed by SecretBox's nonce.
  for (var i = 0; i < gcmNonceLength; i++) {
    if (payload[i] != payload[i + gcmNonceLength]) {
      throw const FormatException('Nonce chiffré incohérent');
    }
  }
  final box = SecretBox.fromConcatenation(
    payload.sublist(gcmNonceLength),
    nonceLength: gcmNonceLength,
    macLength: 16,
  );
  return Uint8List.fromList(await _aes256.decrypt(box, secretKey: key));
}

Future<Uint8List> encryptMessage(SecretKey key, String plaintext) =>
    _encryptBytes(key, utf8.encode(plaintext));

Future<String> decryptMessage(SecretKey key, Uint8List payload) async =>
    utf8.decode(await _decryptBytes(key, payload));

Future<SecretKey> derivePinKey(String pin, Uint8List salt) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac(Sha256()),
    iterations: pbkdf2Iterations,
    bits: aesKeyLength * 8,
  );
  return pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(pin)),
    nonce: salt,
  );
}

Future<Uint8List> encryptLocal(SecretKey key, Uint8List plaintext) =>
    _encryptBytes(key, plaintext);

Future<Uint8List> decryptLocal(SecretKey key, Uint8List payload) =>
    _decryptBytes(key, payload);

Future<Uint8List> generateFileKey() async => randomBytes(aesKeyLength);

Future<Uint8List> encryptFile(SecretKey key, Uint8List bytes) =>
    _encryptBytes(key, bytes);

Future<Uint8List> decryptFile(SecretKey key, Uint8List payload) =>
    _decryptBytes(key, payload);

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes o';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} Go';
}

String safetyFingerprint(Uint8List myPublicKey, Uint8List peerPublicKey) {
  final keys = [myPublicKey, peerPublicKey]..sort((a, b) {
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return a[i] - b[i];
      }
      return 0;
    });
  final digest = crypto_pkg.sha256.convert(keys.expand((k) => k).toList());
  final hexStr = convert.hex.encode(digest.bytes);
  final groups = <String>[];
  for (var i = 0; i < hexStr.length; i += 4) {
    groups.add(
        hexStr.substring(i, i + 4 > hexStr.length ? hexStr.length : i + 4));
  }
  return groups.join(' ');
}
