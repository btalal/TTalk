import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talmessenger/crypto/e2e_crypto.dart';
import 'package:talmessenger/models/group.dart';
import 'package:talmessenger/models/message.dart';

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

  group('Accusés de lecture (modèle)', () {
    test('le statut read est persisté et vaut false par défaut', () {
      final m = ChatMessage(
        id: 'm1',
        conversationId: 'c1',
        fromMe: true,
        ciphertext: [1, 2, 3],
        timestamp: DateTime(2025, 1, 1),
        plaintext: 'salut',
      );
      expect(m.read, isFalse);
      m.read = true;
      final restored = ChatMessage.fromJson(m.toJson());
      expect(restored.read, isTrue);
      expect(restored.plaintext, 'salut');
    });

    test('les anciens messages sans champ read restent lisibles (false)', () {
      final legacy = ChatMessage.fromJson({
        'id': 'm2',
        'conversationId': 'c1',
        'fromMe': false,
        'ciphertext': 'AQID',
        'timestamp': '2025-01-01T00:00:00.000',
      });
      expect(legacy.read, isFalse);
    });
  });

  group('Pièces jointes chiffrées', () {
    test('fichier chiffré puis déchiffré = octets identiques', () async {
      final fileKey = SecretKey(await generateFileKey());
      final original = Uint8List.fromList(List.generate(100000, (i) => i % 256));
      final enc = await encryptFile(fileKey, original);
      expect(enc.length, greaterThan(original.length));
      final dec = await decryptFile(fileKey, enc);
      expect(dec, equals(original));
    });

    test('déchiffrement de fichier échoue avec une mauvaise clé', () async {
      final k1 = SecretKey(await generateFileKey());
      final k2 = SecretKey(await generateFileKey());
      final enc = await encryptFile(k1, Uint8List.fromList([1, 2, 3, 4]));
      expect(() => decryptFile(k2, enc), throwsA(anything));
    });

    test('formatFileSize', () {
      expect(formatFileSize(512), '512 o');
      expect(formatFileSize(2048), '2.0 Ko');
      expect(formatFileSize(5 * 1024 * 1024), '5.0 Mo');
    });
  });

  group('Groupes (modèle)', () {
    test('GroupInvite sérialise/désérialise la clé de groupe + admins + époque', () {
      final invite = GroupInvite(
        groupId: 'g1',
        name: 'Famille',
        groupKeyB64: base64Encode(List.generate(32, (i) => i)),
        memberIds: const ['a', 'b'],
        adminIds: const ['a'],
        epoch: 3,
        fromId: 'a',
        fromName: 'Alice',
      );
      final back = GroupInvite.fromJsonString(invite.toJsonString(), fromId: 'a', fromName: 'Alice');
      expect(back.groupId, 'g1');
      expect(back.name, 'Famille');
      expect(base64Decode(back.groupKeyB64), List.generate(32, (i) => i));
      expect(back.memberIds, ['a', 'b']);
      expect(back.adminIds, ['a']);
      expect(back.epoch, 3);
    });

    test('Group: isAdmin reflète adminIds', () {
      final g = Group(
        id: 'g1',
        name: 'Test',
        memberIds: const ['a', 'b'],
        createdBy: 'a',
        createdAt: DateTime(2025, 1, 1),
        adminIds: const ['a'],
      );
      expect(g.isAdmin('a'), isTrue);
      expect(g.isAdmin('b'), isFalse);
    });

    test('GroupControl: remove avec nouvelle clé pivotée', () {
      final c = GroupControl(
        kind: 'remove',
        groupId: 'g1',
        memberIds: const ['a'],
        adminIds: const ['a'],
        epoch: 2,
        newGroupKeyB64: base64Encode(List.generate(32, (i) => 255 - i)),
        removedId: 'b',
      );
      final back = GroupControl.fromJsonString(c.toJsonString());
      expect(back.kind, 'remove');
      expect(back.removedId, 'b');
      expect(back.epoch, 2);
      expect(base64Decode(back.newGroupKeyB64!), List.generate(32, (i) => 255 - i));
    });

    test('GroupControl: leave sans nouvelle clé', () {
      final c = GroupControl(
        kind: 'leave',
        groupId: 'g1',
        memberIds: const ['a'],
        adminIds: const ['a'],
        epoch: 1,
        removedId: 'c',
      );
      final back = GroupControl.fromJsonString(c.toJsonString());
      expect(back.newGroupKeyB64, isNull);
      expect(back.kind, 'leave');
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
