# 🔒 TTalk 0.5.0 — Windows x64

🟢 **Version stable historique** · Première version Windows 0.5 compatible
avec le client Android stable. Pour une nouvelle installation, préférer
[TTalk 0.5.1](https://github.com/btalal/TTalk/releases/tag/v0.5.1-windows).

## Téléchargements

- 📦 [Archive Windows x64 0.5.0](https://github.com/btalal/TTalk/releases/download/v0.5.0-windows/ttalk-windows-x64.zip)
- 🔐 [Empreinte SHA256 du ZIP](https://github.com/btalal/TTalk/releases/download/v0.5.0-windows/ttalk-windows-x64.zip.sha256)
- 📱 [Android 0.5.0](https://github.com/btalal/TTalk/releases/tag/android-v0.5.0)

## Pour qui ?

Pour les personnes devant conserver la version 0.5.0. Les nouveaux utilisateurs
devraient installer la version stable 0.5.1, qui corrige plusieurs problèmes.

## Nouveautés

- Messages et fichiers entre Windows et Android via le même relais.
- Contacts et historique conservés après redémarrage.
- Livraison des messages en attente lors de la reconnexion.
- Groupes et transfert de propriété.

## Corrections

Les correctifs de gestion des conversations et d’appairage sont publiés dans
la [version 0.5.1](https://github.com/btalal/TTalk/releases/tag/v0.5.1-windows).

## Compatibilité

| Plateforme | État |
|---|---|
| Windows 10/11 x64 | ✅ Cette archive stable |
| Android 7.0+ | ✅ [APK 0.5.0 séparé](https://github.com/btalal/TTalk/releases/tag/android-v0.5.0) |
| iPhone | 🟡 Préversion séparée ; essais sur appareil réel encore nécessaires |

Les échanges Windows et Android de ce périmètre ont été testés sur deux PC
Windows x64 et un smartphone Android. Un relais TTalk HTTPS est nécessaire.

## Mise à niveau

Extraire tout le ZIP, puis lancer `TTalk.exe` en conservant `app/` à côté.
Depuis 0.3.6, le PIN, les clés et l’historique sont conservés ; les anciens
groupes restent consultables mais **doivent être recréés** avec le nouveau
relais. Pour passer ensuite à 0.5.1, consulter ses notes de version.

## Sécurité

Les conversations directes utilisent X25519, HKDF-SHA256 et AES-256-GCM.
Le coffre local est dérivé du PIN avec PBKDF2-HMAC-SHA256. Comparez les
numéros de sécurité des contacts par un autre canal. Le relais peut voir des
métadonnées ; TTalk n’a pas été audité indépendamment.

## Vérification SHA256

Le fichier `.sha256` accompagne le ZIP. Comparer son empreinte avec celle
obtenue par `Get-FileHash .\ttalk-windows-x64.zip -Algorithm SHA256` sous
PowerShell. Les liens « Source code » ne sont pas l’application Windows.

## Documentation

[Démarrage](https://github.com/btalal/TTalk/blob/main/ttalk/docs/GETTING_STARTED.md) ·
[Installation mobile](https://github.com/btalal/TTalk/blob/main/ttalk/docs/MOBILE_INSTALL.md) ·
[Sécurité et limites](https://github.com/btalal/TTalk/blob/main/ttalk/docs/SECURITY.md)
