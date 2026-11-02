import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttalk/services/relay_client.dart';

void main() {
  test('registration retains identity and group events are processed in order',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    WebSocket? socket;
    server.listen((request) async {
      socket = await WebSocketTransformer.upgrade(request);
      socket!.listen((data) {
        if (jsonDecode(data as String)['type'] == 'register') {
          socket!.add(jsonEncode({'type': 'registered', 'id': 'alice'}));
          socket!.add(jsonEncode({'type': 'event', 'sequence': 1}));
          socket!.add(jsonEncode({'type': 'event', 'sequence': 2}));
        }
      });
    });
    final done = Completer<void>();
    final order = <String>[];
    final relay = RelayClient();
    relay.onInbound = (message) async {
      if (message['type'] == 'registered') {
        expect(relay.myId, 'alice');
      } else {
        final sequence = message['sequence'];
        order.add('start $sequence');
        if (sequence == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }
        order.add('end $sequence');
        if (sequence == 2) done.complete();
      }
    };
    try {
      await relay.connect('ws://127.0.0.1:${server.port}');
      relay.register(name: 'Alice', publicKey: Uint8List(32));
      await done.future.timeout(const Duration(seconds: 5));
      expect(relay.displayName, 'Alice');
      expect(order, ['start 1', 'end 1', 'start 2', 'end 2']);
    } finally {
      relay.disconnect();
      await socket?.close();
      await server.close(force: true);
    }
  });
}
