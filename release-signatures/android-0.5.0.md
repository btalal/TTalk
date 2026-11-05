# 🔒 TTalk 0.5.0 — Android

🟢 **Version stable historique** · Première version Android stable de TTalk.
Pour une nouvelle installation, préférer
[TTalk Android 0.5.1](https://github.com/btalal/TTalk/releases/tag/android-v0.5.1).

## Téléchargements

- 📦 [APK Android signé 0.5.0](https://github.com/btalal/TTalk/releases/download/android-v0.5.0/ttalk-android.apk)
- 🔐 [Empreinte SHA256 de l’APK signé](https://github.com/btalal/TTalk/releases/download/android-v0.5.0/ttalk-android.apk.sha256)
- 🖥️ [Windows 0.5.0](https://github.com/btalal/TTalk/releases/tag/v0.5.0-windows)

`ttalk-android-unsigned.apk` est une archive de compilation, pas le package
à installer sur un téléphone.

## Pour qui ?

Pour les utilisateurs qui doivent rester sur la version 0.5.0. La version
0.5.1 contient des corrections supplémentaires.

## Nouveautés

- Premier APK signé stable pour Android 7.0 et versions ultérieures.
- Messages et fichiers compatibles avec TTalk Windows via le même relais.
- Contacts, historique et groupes conservés après redémarrage.
- Transfert de propriété des groupes et réception différée à la réouverture.

## Corrections

Les correctifs d’appairage et de gestion des conversations sont publiés dans
la [version 0.5.1](https://github.com/btalal/TTalk/releases/tag/android-v0.5.1).

## Compatibilité

| Plateforme | État |
|---|---|
| Android 7.0+ | ✅ APK signé ; ARM64, ARMv7 et x86_64 |
| Windows 10/11 x64 | ✅ [ZIP 0.5.0 séparé](https://github.com/btalal/TTalk/releases/tag/v0.5.0-windows) |
| iPhone | 🟡 Préversion séparée |

Les notifications push et la réception permanente quand l’application est
fermée ne sont pas intégrées. Un relais TTalk HTTPS est nécessaire.

## Mise à niveau

Pour passer de la préversion Android à 0.5.0 ou de 0.5.0 à 0.5.1, installer
l’APK signé **sans désinstaller TTalk**. La même clé de signature est utilisée ;
la désinstallation effacerait les données locales.

## Sécurité

X25519 et HKDF-SHA256 établissent les clés des conversations directes ;
AES-256-GCM chiffre les messages et fichiers. Le coffre local utilise
PBKDF2-HMAC-SHA256 ; l’identité est conservée dans le stockage sécurisé
Android. Comparez les numéros de sécurité des contacts. Le relais voit des
métadonnées et TTalk n’a pas été audité indépendamment.

## Vérification SHA256

Comparer l’empreinte de `ttalk-android.apk` avec le fichier
[`ttalk-android.apk.sha256`](https://github.com/btalal/TTalk/releases/download/android-v0.5.0/ttalk-android.apk.sha256).
La somme de contrôle ne remplace pas la vérification de la signature Android.

## Documentation

[Installation mobile](https://github.com/btalal/TTalk/blob/main/ttalk/docs/MOBILE_INSTALL.md) ·
[Sécurité et limites](https://github.com/btalal/TTalk/blob/main/ttalk/docs/SECURITY.md) ·
[Relais](https://github.com/btalal/TTalk/blob/main/ttalk/server/README.md)
