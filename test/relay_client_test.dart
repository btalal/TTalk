import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttalk/models/outbound_packet.dart';
import 'package:ttalk/services/relay_client.dart';
import 'package:ttalk/state/app_state.dart';

import 'support/group_fakes.dart';

Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 12));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Protocol condition not reached');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  test('real Flutter/Node protocol: durable identity, offline delivery, encrypted ACKs and local outbox', () async {
    final directory = await Directory.systemTemp.createTemp('ttalk-protocol-');
    Process? server;
    int port = 0;
    Future<void> start() async {
      server = await Process.start(
        'node',
        ['server/relay.js'],
        environment: {
          'PORT': '$port',
          'HOST': '127.0.0.1',
          'DATA_DIR': directory.path,
        },
      );
      final errors = <String>[];
      server!.stderr.transform(utf8.decoder).listen(errors.add);
      final line = await server!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .firstWhere((line) => line.contains('TTalk relay listening'))
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw StateError('Relay startup failed: $errors'),
          );
      port = int.parse(
        RegExp(r'127\.0\.0\.1:(\d+)').firstMatch(line)!.group(1)!,
      );
    }

    Future<void> stop() async {
      server?.kill();
      await server?.exitCode;
      server = null;
    }

    final aliceStore = MemoryStore(), bobStore = MemoryStore();
    final aliceRelay = RelayClient(), bobRelay = RelayClient();
    final alice = AppState(store: aliceStore, relay: aliceRelay);
    AppState bob = AppState(store: bobStore, relay: bobRelay);
    AppState? restoredAlice;
    try {
      await start();
      await alice.init(pin: '1234');
      await bob.init(pin: '1234');
      final url = 'ws://127.0.0.1:$port/ws';
      await alice.connectRelay(url);
      await bob.connectRelay(url);
      await until(() => alice.registered && bob.registered);
      final aliceId = alice.myId, bobId = bob.myId;
      expect(aliceId, alice.identity!.stableId);
      expect(bobId, bob.identity!.stableId);
      bool codeReady = false;
      final inbound = aliceRelay.onInbound;
      aliceRelay.onInbound = (message) async {
        await inbound?.call(message);
        if (message['type'] == 'pairing_code') codeReady = true;
      };
      aliceRelay.startPairing();
      await until(() => codeReady);
      bobRelay.answerPairing(aliceRelay.myPairingCode!);
      await until(
        () => alice.conversations.length == 1 && bob.conversations.length == 1,
      );
      bob.dispose();
      await alice.sendMessage(
        alice.conversations.single.id,
        'message après redémarrage',
      );
      await until(() => alice.pendingCount == 0);
      expect(alice.messagesByConv.values.single.single.delivered, isFalse);
      for (final file in directory.listSync().whereType<File>()) {
        expect(
          utf8.decode(await file.readAsBytes(), allowMalformed: true),
          isNot(contains('message après redémarrage')),
        );
      }
      await stop();
      await until(() => !alice.registered);
      await start();
      // Alice reconnects automatically, without manual re-pairing.
      await until(() => alice.registered);
      expect(alice.myId, aliceId);
      bob = AppState(store: bobStore, relay: RelayClient());
      await bob.init(pin: '1234');
      await bob.connectRelay(url);
      await until(
        () => bob.messagesByConv.values.any((messages) => messages.isNotEmpty),
      );
      expect(bob.myId, bobId);
      expect(
        bob.messagesByConv.values.single.single.plaintext,
        'message après redémarrage',
      );
      await until(() => alice.messagesByConv.values.single.single.delivered);
      expect(alice.messagesByConv.values.single.single.read, isFalse);
      await bob.markConversationRead(bob.conversations.single.id);
      await until(() => alice.messagesByConv.values.single.single.read);

      bobStore.failWrites = true;
      await alice.sendMessage(
        alice.conversations.single.id,
        'après panne de stockage',
      );
      await until(() => !bob.registered);
      bobStore.failWrites = false;
      await until(() => bob.registered && bobStore.savedMessages.length == 2);
      await until(() => alice.messagesByConv.values.single.last.delivered);
      expect(bobStore.savedMessages.last.plaintext, 'après panne de stockage');

      // A copied payload cannot be relabelled with another transport ID.
      final first = alice.messagesByConv.values.single.first;
      aliceRelay.sendPacket(
        OutboundPacket(
          id: 'tampered',
          type: 'cipher',
          recipients: [bobId!],
          payload: Uint8List.fromList(first.ciphertext),
        ),
        [bobId],
      );
      await until(() => bob.error != null);
      expect(bob.messagesByConv.values.single, hasLength(2));

      aliceRelay.disconnect();
      await alice.sendMessage(
        alice.conversations.single.id,
        'envoyé depuis le coffre hors ligne',
      );
      expect(alice.pendingCount, 1);
      alice.dispose();
      restoredAlice = AppState(store: aliceStore, relay: RelayClient());
      await restoredAlice.init(pin: '1234');
      expect(restoredAlice.pendingCount, 1);
      await restoredAlice.connectRelay(url);
      await until(() => bob.messagesByConv.values.single.length == 3);
      await until(() => restoredAlice!.pendingCount == 0);
      expect(restoredAlice.myId, aliceId);
      expect(
        bob.messagesByConv.values.single.last.plaintext,
        'envoyé depuis le coffre hors ligne',
      );
    } finally {
      if (restoredAlice == null) {
        alice.dispose();
      } else {
        restoredAlice.dispose();
      }
      bob.dispose();
      await stop();
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(seconds: 60)));
}
