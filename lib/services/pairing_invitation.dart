import 'dart:convert';
import 'dart:typed_data';

import '../crypto/e2e_crypto.dart';
import 'relay_client.dart';

/// QR and clipboard invitations are untrusted input, never instructions to
/// switch servers silently. A fingerprint is checked after relay pairing.
class PairingInvitation {
  PairingInvitation({required this.code, required this.relay, this.peerId});
  final String code;
  final String relay;
  final String? peerId;

  String get link => Uri(
    scheme: 'ttalk',
    host: 'pair',
    queryParameters: {
      'v': '1',
      'code': code,
      'relay': relay,
      if (peerId != null) 'peer': peerId!,
    },
  ).toString();

  factory PairingInvitation.parse(String input) {
    if (input.length > 2048) {
      throw const FormatException('Invitation trop longue.');
    }
    final value = input.trim();
    if (RegExp(r'^[A-Za-z0-9]{6}$').hasMatch(value)) {
      return PairingInvitation(code: value.toUpperCase(), relay: '');
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'ttalk' ||
        uri.host != 'pair' ||
        uri.path.isNotEmpty ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        uri.queryParametersAll.values.any((v) => v.length != 1) ||
        uri.queryParameters['v'] != '1') {
      throw const FormatException('Invitation TTalk invalide.');
    }
    final code = uri.queryParameters['code'] ?? '';
    final relay = RelayClient.normalizeUrl(uri.queryParameters['relay'] ?? '');
    final peer = uri.queryParameters['peer'];
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(code) ||
        (peer != null && !RegExp(r'^[a-f0-9]{64}$').hasMatch(peer))) {
      throw const FormatException('Code ou identité invalide.');
    }
    return PairingInvitation(code: code, relay: relay, peerId: peer);
  }
}

String publicKeyFingerprint(String encoded) =>
    identityId(Uint8List.fromList(base64Decode(encoded)));
