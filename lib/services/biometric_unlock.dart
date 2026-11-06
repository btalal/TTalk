import 'dart:io';

import 'package:biometric_storage/biometric_storage.dart';

/// The vault key is released by a biometric-protected Keychain/Keystore item.
/// Never fall back to this plugin's unprotected desktop/web implementation.
class BiometricUnlock {
  bool get supportedPlatform =>
      Platform.isIOS || Platform.isAndroid || Platform.isMacOS;
  Future<bool> available() async {
    if (!supportedPlatform) return false;
    try {
      return await BiometricStorage().canAuthenticate() ==
          CanAuthenticateResponse.success;
    } catch (_) {
      return false;
    }
  }

  Future<BiometricStorageFile> _file() {
    if (!supportedPlatform) throw UnsupportedError('Biométrie indisponible.');
    return BiometricStorage().getStorage(
      'ttalk.vault-key.v1',
      options: StorageFileInitOptions(
        authenticationRequired: true,
        authenticationValidityDurationSeconds: -1,
        androidBiometricOnly: true,
        darwinBiometricOnly: true,
      ),
    );
  }

  Future<void> enable(String key) async => (await _file()).write(key);
  Future<String?> read() async => (await _file()).read();
  Future<void> disable() async {
    if (supportedPlatform) await (await _file()).delete();
  }
}
