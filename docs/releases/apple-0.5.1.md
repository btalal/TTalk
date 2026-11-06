# TTalk 0.5.1 — iPhone et Mac · Versions finales

**Versions finales pour installation avec signature personnelle dans Xcode.**
Essais confirmés par le propriétaire le **6 novembre 2026** sur :

- **iPhone 17 Pro sous iOS 27.2** : installation Release, lancement depuis
  l’icône sans Xcode, serveur, ajout d’un contact, messages envoyés et reçus.
- **Mac mini M4 sous macOS 27.2** : installation Release signée localement,
  lancement depuis Applications, serveur, contacts, messages envoyés/reçus et
  conservation des messages reçus après fermeture et réouverture.

## Installation

- **iPhone, iOS 15 minimum** : ouvrir `ios/Runner.xcworkspace`, choisir sa
  Personal Team, l’iPhone et **Run > Release**, puis lancer depuis Xcode.
  Avec un compte Apple gratuit, renouveler la signature après **7 jours**,
  sans désinstaller, avec le même compte et l’identifiant `com.talal.ttalk`.
- **Mac, macOS 12 minimum** : le projet natif `macos/` est fourni avec l’icône
  TTalk, le réseau sortant et le Trousseau. Ouvrir `macos/Runner.xcworkspace`,
  configurer la Personal Team, choisir **My Mac** et **Release**, compiler,
  puis copier `ttalk.app` dans Applications.
- Outils utilisés : **Flutter 3.47.9, CocoaPods 1.17.0 et Xcode 27.2**.
- Dans **Configurer le serveur**, saisir `https://ttalk.fly.dev`, ou votre
  propre relais HTTPS. Appairer séparément chaque appareil.

Les fichiers `ttalk-ios-unsigned.ipa` et `ttalk-macos-unsigned.zip` sont des
compilations CI **non signées**, à destination des développeurs. Ils ne
s’installent pas directement. Aucune clé ou signature personnelle du propriétaire
n’est distribuée. Le Mac n’a pas de signature Developer ID ni de notarisation ;
la publication ne constitue pas une distribution App Store ou TestFlight.
Les fichiers `.sha256` permettent de vérifier l’intégrité des téléchargements.

## Périmètre

Le protocole 2 et le code commun de messagerie restent ceux de la version 0.5.1.
Le lancement autonome iPhone exige une compilation Release. Les caches Flutter
Intel mal détectés sur Apple Silicon sont documentés dans le guide Mac.

Ces essais Apple ne couvrent pas les groupes, pièces jointes, interruptions réseau,
migrations et autres scénarios détaillés dans le compte rendu. Pas de notifications
push ni de réception mobile permanente garantie en arrière-plan. La version Intel
du Mac et les anciens systèmes n’ont pas été testés sur appareils réels pendant
cette validation. TTalk n’a pas été audité indépendamment.

## Documentation

[Installation iPhone](https://github.com/btalal/TTalk/blob/main/ttalk/docs/MOBILE_INSTALL.md) ·
[Installation Mac](https://github.com/btalal/TTalk/blob/main/ttalk/docs/MACOS_INSTALL.md) ·
[Compte rendu des essais](https://github.com/btalal/TTalk/blob/main/ttalk/docs/APPLE_VALIDATION.md) ·
[Sécurité](https://github.com/btalal/TTalk/blob/main/ttalk/docs/SECURITY.md)

Les préversions antérieures restent archivées. Pour Windows et Android, les
versions finales 0.5.1 sont publiées dans leurs releases dédiées.
