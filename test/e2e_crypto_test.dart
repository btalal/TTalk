import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talmessenger/crypto/e2e_crypto.dart';

void main() {
  group('E2E encryption', () {
    test('deux identités dérivent la même clé de session', () async {
      final alice = await IdentityKeys.generate();
      final bob = await IdentityKeys.generate();
      final keyAB = await alice.deriveSessionKey(bob.publicKey);
      final keyBA = await bob.deriveSessionKey(alice.publicKey);
      final ab = await keyAB.extractBytes();
      final ba = await keyBA.extractBytes();
      expect(ab, equals(ba));
      expect(ab.length, aesKeyLength);
    });

    test('chiffrement/déchiffrement aller-retour', () async {
      final alice = await IdentityKeys.generate();
      final bob = await IdentityKeys.generate();
      final key = await alice.deriveSessionKey(bob.publicKey);
      const plaintext = 'Bonjour 👋 — message secret !';
      final cipher = await encryptMessage(key, plaintext);
      expect(cipher.length, greaterThan(plaintext.length));
      final decrypted = await decryptMessage(key, cipher);
      expect(decrypted, equals(plaintext));
    });

    test('le déchiffrement échoue avec une mauvaise clé', () async {
      final alice = await IdentityKeys.generate();
      final bob = await IdentityKeys.generate();
      final eve = await IdentityKeys.generate();
      final keyAlice = await alice.deriveSessionKey(bob.publicKey);
      final keyEve = await eve.deriveSessionKey(bob.publicKey);
      final cipher = await encryptMessage(keyAlice, 'secret');
      expect(
        () => decryptMessage(keyEve, cipher),
        throwsA(anything),
      );
    });

    test('deux chiffrements du même texte sont différents (nonce aléatoire)', () async {
      final alice = await IdentityKeys.generate();
      final bob = await IdentityKeys.generate();
      final key = await alice.deriveSessionKey(bob.publicKey);
      final c1 = await encryptMessage(key, 'même texte');
      final c2 = await encryptMessage(key, 'même texte');
      expect(c1, isNot(equals(c2)));
    });
  });

  group('Stockage local (PIN)', () {
    test('dérivation PIN + chiffrement local aller-retour', () async {
      final salt = randomBytes(saltLength);
      final key = await derivePinKey('1234', salt);
      final data = Uint8List.fromList(utf8.encode('données secrètes'));
      final blob = await encryptLocal(key, data);
      final clear = await decryptLocal(key, blob);
      expect(clear, equals(data));
    });

    test('un mauvais PIN produit une clé qui échoue au déchiffrement', () async {
      final salt = randomBytes(saltLength);
      final goodKey = await derivePinKey('1234', salt);
      final badKey = await derivePinKey('0000', salt);
      final blob = await encryptLocal(goodKey, Uint8List.fromList([1, 2, 3]));
      expect(() => decryptLocal(badKey, blob), throwsA(anything));
    });
  });

  group('Numéro de sécurité', () {
    test('est identique quel que soit l\'ordre des clés', () {
      final a = Uint8List.fromList(List.generate(32, (i) => i));
      final b = Uint8List.fromList(List.generate(32, (i) => 255 - i));
      expect(safetyFingerprint(a, b), equals(safetyFingerprint(b, a)));
      expect(safetyFingerprint(a, b).split(' ').length, 16);
    });

    test('dépend des clés', () {
      final a = Uint8List.fromList(List.generate(32, (i) => i));
      final b = Uint8List.fromList(List.generate(32, (i) => 255 - i));
      final c = Uint8List.fromList(List.generate(32, (i) => i + 1));
      expect(safetyFingerprint(a, b), isNot(equals(safetyFingerprint(a, c))));
    });
  });

  group('Sérialisation', () {
    test('SecretKey dérivé reste utilisable après extraction', () async {
      final alice = await IdentityKeys.generate();
      final bob = await IdentityKeys.generate();
      final key = await alice.deriveSessionKey(bob.publicKey);
      final cipher = await encryptMessage(key, 'test');
      final rederived = await bob.deriveSessionKey(alice.publicKey);
      expect(await decryptMessage(rederived, cipher), 'test');
    });
  });
}
