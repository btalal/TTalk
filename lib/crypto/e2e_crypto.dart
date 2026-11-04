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
  return Uint8List.fromList(List<int>.generate(length, (_) => rng.nextInt(256)));
}

class IdentityKeys {
  IdentityKeys({required this.publicKey, required this.privateKey});

  final SimpleKeyPair privateKey;
  final Uint8List publicKey;

  static Future<IdentityKeys> generate() async {
    final kp = await X25519().newKeyPair();
    final pub = await kp.extractPublicKey();
    return IdentityKeys(privateKey: kp, publicKey: Uint8List.fromList(pub.bytes));
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

Future<Uint8List> encryptMessage(SecretKey sessionKey, String plaintext) async {
  final nonce = randomBytes(gcmNonceLength);
  final box = await AesGcm.with256bits().encrypt(
    utf8.encode(plaintext),
    secretKey: sessionKey,
    nonce: nonce,
  );
  final out = BytesBuilder(copy: false);
  out.add(nonce);
  out.add(box.concatenation());
  return out.toBytes();
}

Future<String> decryptMessage(SecretKey sessionKey, Uint8List payload) async {
  if (payload.length < gcmNonceLength + 16) {
    throw const FormatException('Paquet chiffré trop court');
  }
  final box = SecretBox.fromConcatenation(
    payload.sublist(gcmNonceLength),
    nonceLength: gcmNonceLength,
    macLength: 16,
  );
  final clear = await AesGcm.with256bits().decrypt(box, secretKey: sessionKey);
  return utf8.decode(clear);
}

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

Future<Uint8List> encryptLocal(SecretKey pinKey, Uint8List plaintext) async {
  final nonce = randomBytes(gcmNonceLength);
  final box = await AesGcm.with256bits().encrypt(
    plaintext,
    secretKey: pinKey,
    nonce: nonce,
  );
  final out = BytesBuilder(copy: false);
  out.add(nonce);
  out.add(box.concatenation());
  return out.toBytes();
}

Future<Uint8List> decryptLocal(SecretKey pinKey, Uint8List payload) async {
  final box = SecretBox.fromConcatenation(
    payload.sublist(gcmNonceLength),
    nonceLength: gcmNonceLength,
    macLength: 16,
  );
  return Uint8List.fromList(
    await AesGcm.with256bits().decrypt(box, secretKey: pinKey),
  );
}

Future<Uint8List> generateFileKey() async {
  return randomBytes(aesKeyLength);
}

Future<Uint8List> encryptFile(SecretKey fileKey, Uint8List fileBytes) async {
  final nonce = randomBytes(gcmNonceLength);
  final box = await AesGcm.with256bits().encrypt(
    fileBytes,
    secretKey: fileKey,
    nonce: nonce,
  );
  final out = BytesBuilder(copy: false);
  out.add(nonce);
  out.add(box.concatenation());
  return out.toBytes();
}

Future<Uint8List> decryptFile(SecretKey fileKey, Uint8List payload) async {
  final box = SecretBox.fromConcatenation(
    payload.sublist(gcmNonceLength),
    nonceLength: gcmNonceLength,
    macLength: 16,
  );
  return Uint8List.fromList(
    await AesGcm.with256bits().decrypt(box, secretKey: fileKey),
  );
}

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
    groups.add(hexStr.substring(i, i + 4 > hexStr.length ? hexStr.length : i + 4));
  }
  return groups.join(' ');
}
