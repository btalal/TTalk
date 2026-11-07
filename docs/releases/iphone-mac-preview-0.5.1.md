# TTalk 0.5.1 — iPhone et macOS · Préversion historique

Cette publication est conservée comme archive historique. Utiliser désormais
la [version finale Apple 0.5.1](https://github.com/btalal/TTalk/releases/tag/v0.5.1-apple),
validée sur iPhone 17 Pro (iOS 27.2) et Mac mini M4 le 6 novembre 2026.
Les informations ci-dessous décrivent l’état de la préversion à sa publication.

🟡 **Préversion de test** · Ces archives ne constituent pas une distribution
signée et prête à installer sur tous les appareils.

Cette préversion apporte le code commun de TTalk sur iPhone et une application
Flutter native pour Mac. Les essais sur iPhone et Mac réels restent à compléter.

## Téléchargements

- 🍏 [IPA iPhone **non signé**](https://github.com/btalal/TTalk/releases/download/v0.5.1-iphone-mac-preview.1/ttalk-ios-unsigned.ipa) — `ttalk-ios-unsigned.ipa`
- 🔐 [SHA256 de l’IPA](https://github.com/btalal/TTalk/releases/download/v0.5.1-iphone-mac-preview.1/ttalk-ios-unsigned.ipa.sha256)
- 💻 [Archive macOS **non signée et non notarisée**](https://github.com/btalal/TTalk/releases/download/v0.5.1-iphone-mac-preview.1/ttalk-macos-preview.zip) — `ttalk-macos-preview.zip`
- 🔐 [SHA256 de l’archive Mac](https://github.com/btalal/TTalk/releases/download/v0.5.1-iphone-mac-preview.1/ttalk-macos-preview.zip.sha256)

Pour une installation prête à l’emploi, choisir plutôt
[Windows stable](https://github.com/btalal/TTalk/releases/tag/v0.5.1-windows)
ou [Android stable](https://github.com/btalal/TTalk/releases/tag/v0.5.1-android).

## Pour qui ?

Pour les testeurs disposant d’un Mac récent et d’un compte Apple pour signer
l’application iPhone, ou souhaitant compiler la version Mac depuis les sources.
L’IPA téléchargée **ne s’installe pas directement** sur un iPhone.

## Nouveautés

- Préversion iPhone utilisant le même protocole chiffré que Windows et Android.
- Application macOS native Flutter compilée pour Apple Silicon et Intel.
- Identité propre à chaque appareil : appairage séparé et comparaison des
  numéros de sécurité avec les contacts.

## Corrections

Cette préversion reprend le code commun de la 0.5.1 ; aucun correctif propre
à iPhone ou macOS n’est annoncé dans cette publication.

## Compatibilité

| Plateforme | État |
|---|---|
| iPhone, iOS 15+ | 🟡 Compilation et tests sur simulateur ; appareil réel à valider |
| Mac Apple Silicon et Intel | 🟡 Compilation vérifiée ; échanges sur Mac réel à valider |
| Windows et Android | 🟢 [Versions stables séparées](https://github.com/btalal/TTalk/releases/tag/v0.5.1-windows) |

Les notifications push et la réception garantie lorsque l’application mobile
est fermée ne sont pas intégrées. Un relais TTalk HTTPS est nécessaire ;
`https://ttalk.fly.dev` a servi aux essais de cette préversion.

## Mise à niveau et installation

- **iPhone :** signer l’IPA avec votre compte Apple, ou compiler et signer
  l’application dans Xcode sur un Mac. Un compte gratuit exige généralement
  un renouvellement du profil après sept jours. Lire
  [`INSTALLATION.md`](https://github.com/btalal/TTalk/releases/download/v0.5.1-iphone-mac-preview.1/INSTALLATION.md).
- **Mac :** l’archive n’a ni signature Developer ID ni notarisation. macOS
  peut refuser son ouverture. Le [guide Mac](https://github.com/btalal/TTalk/releases/download/v0.5.1-iphone-mac-preview.1/MACOS_INSTALL.md)
  décrit la compilation locale depuis les sources.

Chaque nouvel appareil doit être appairé séparément. Aucune migration
automatique de l’historique depuis un autre appareil n’est annoncée.

## Sécurité

Le code commun utilise X25519, HKDF-SHA256 et AES-256-GCM pour les échanges,
ainsi que PBKDF2-HMAC-SHA256 pour le coffre local. Les clés d’identité sont
conservées dans le Trousseau iOS sur iPhone. Comparez les numéros de sécurité
des contacts par un autre canal. Le relais voit des métadonnées de routage ;
TTalk n’a pas été audité indépendamment.

## Vérification SHA256

Comparer chaque archive téléchargée à son fichier `.sha256` ci-dessus.
Ces empreintes vérifient l’intégrité du téléchargement ; elles ne signent
pas les applications pour Apple.

## Documentation

[Installation iPhone et Android](https://github.com/btalal/TTalk/blob/main/ttalk/docs/MOBILE_INSTALL.md) ·
[Sécurité et limites](https://github.com/btalal/TTalk/blob/main/ttalk/docs/SECURITY.md) ·
[Relais](https://github.com/btalal/TTalk/blob/main/ttalk/server/README.md)

Pour signaler un problème, ouvrir une [issue GitHub](https://github.com/btalal/TTalk/issues)
avec le modèle d’appareil et les étapes de reproduction, sans publier de
message privé, code d’appairage ou secret.
