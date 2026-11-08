# 🔒 TTalk 0.5.1 — iPhone et macOS

🟢 **Stable — versions finales pour installation avec signature personnelle dans Xcode.**
Les archives GitHub sont **non signées** : elles ne constituent pas des packages
prêts à installer directement sur tous les appareils Apple.

Cette version reprend TTalk 0.5.1 sur iPhone et Mac. Le parcours Release a été
validé le **6 novembre 2026** sur **iPhone 17 Pro sous iOS 27.2** et **Mac mini M4
sous macOS 27.2** : serveur, contacts, envoi/réception et lancement autonome.

## Téléchargements

- 🍏 [IPA iPhone **non signé**](https://github.com/btalal/TTalk/releases/download/v0.5.1-apple/ttalk-ios-unsigned.ipa) — `ttalk-ios-unsigned.ipa`
- 🔐 [SHA256 de l’IPA](https://github.com/btalal/TTalk/releases/download/v0.5.1-apple/ttalk-ios-unsigned.ipa.sha256)
- 💻 [Archive macOS **non signée et non notarisée**](https://github.com/btalal/TTalk/releases/download/v0.5.1-apple/ttalk-macos-unsigned.zip) — `ttalk-macos-unsigned.zip`
- 🔐 [SHA256 de l’archive Mac](https://github.com/btalal/TTalk/releases/download/v0.5.1-apple/ttalk-macos-unsigned.zip.sha256)

Le parcours d’installation validé utilise les **sources**, compilées en Release
puis signées personnellement dans Xcode. Les archives ci-dessus sont des résultats
de compilation destinés aux développeurs, pas des installateurs Apple signés.
L’archive « Source code » contient le projet à compiler, pas une application installable.

[Windows stable](https://github.com/btalal/TTalk/releases/tag/v0.5.1-windows) et
[Android stable](https://github.com/btalal/TTalk/releases/tag/v0.5.1-android)
restent disponibles dans leurs publications séparées.

## Pour qui ?

Pour les utilisateurs disposant d’un Mac avec Xcode et d’un compte Apple pour
compiler et signer personnellement TTalk sur iPhone ou Mac.
Les utilisateurs finaux ne disposent pas encore d’une distribution App Store,
TestFlight ou d’un package Mac Developer ID notarisé.

## Nouveautés

- Versions finales iPhone et macOS pour le parcours d’installation personnelle
  validé sur appareils réels.
- Projet natif `macos/` inclus dans le dépôt, avec l’icône TTalk commune à iPhone,
  l’accès réseau sortant et la configuration du Trousseau.
- Guides d’installation en Release pour ouvrir l’application depuis son icône,
  sans session Xcode active.
- Identité propre à chaque appareil : appairage séparé et comparaison des
  numéros de sécurité avec les contacts.

## Corrections

- Configuration du lancement Xcode en Release pour le parcours autonome.
- Remplacement de l’icône Flutter par défaut par l’icône TTalk dans le projet Mac.
- Documentation de la sélection de Xcode complet, du PATH CocoaPods et des caches
  Flutter Intel mal détectés sur Apple Silicon (`impellerc`, `font-subset`).
- Instructions de signature pour le Trousseau et de copie de `ttalk.app` dans
  Applications ; aucun compte ni certificat Apple personnel inclus dans le dépôt.

Le code commun de messagerie et le protocole 2 restent ceux de TTalk 0.5.1.
Les corrections de cache sont locales à l’installation des outils Flutter ;
elles ne modifient pas le protocole ni le code de messagerie.

## Compatibilité

| Plateforme | État |
|---|---|
| iPhone, iOS 15+ | 🟢 Parcours Release validé sur **iPhone 17 Pro, iOS 27.2** ; autres modèles et versions non couverts par ces essais |
| Mac Apple Silicon, macOS 12+ | 🟢 Parcours Release validé sur **Mac mini M4, macOS 27.2** ; M1, M2, M3 et M5 non testés pendant cette validation |
| Mac Intel | Compilation universelle disponible ; aucun essai matériel Intel consigné |
| Windows et Android | 🟢 [Windows 0.5.1](https://github.com/btalal/TTalk/releases/tag/v0.5.1-windows) et [Android 0.5.1](https://github.com/btalal/TTalk/releases/tag/v0.5.1-android), versions stables séparées |

Outils utilisés lors des essais : **Flutter 3.47.9, CocoaPods 1.17.0 et Xcode 27.2**.

Les essais Apple confirment la connexion au relais, l’ajout d’un contact et les
messages envoyés/reçus sur les deux appareils. Le lancement autonome est validé
sur les deux ; la conservation des messages après fermeture et réouverture est
explicitement confirmée sur Mac.

Les groupes, pièces jointes, pertes réseau, migrations et renouvellements de
signature ne sont pas couverts par ces nouveaux essais. Les notifications push
et la réception mobile permanente en arrière-plan ne sont pas intégrées.

Un relais HTTPS est nécessaire. Saisir `https://ttalk.fly.dev`, utilisé lors des
essais, dans **Configurer le serveur**, ou l’adresse de votre propre relais.

## Mise à niveau et installation

- **iPhone :** ouvrir `ios/Runner.xcworkspace`, choisir **Automatically manage
  signing** et votre **Personal Team**, sélectionner l’iPhone et **Run > Release**,
  puis lancer depuis Xcode. Avec un compte gratuit, renouveler la signature après
  **sept jours**, avec le même compte et `com.talal.ttalk`, **sans désinstaller** :
  la désinstallation efface les données locales.
  Lire [`INSTALLATION.md`](https://github.com/btalal/TTalk/releases/download/v0.5.1-apple/INSTALLATION.md).
- **Mac :** ouvrir `macos/Runner.xcworkspace`, choisir votre Personal Team,
  **My Mac** et **Release**, compiler puis copier `ttalk.app` dans Applications.
  Le Trousseau nécessite la signature de développement. L’archive CI n’a ni
  signature Developer ID ni notarisation : macOS peut refuser son ouverture.
  Ne pas désactiver les protections de macOS pour la lancer.
  Lire [`MACOS_INSTALL.md`](https://github.com/btalal/TTalk/releases/download/v0.5.1-apple/MACOS_INSTALL.md).

Conserver le même compte et identifiant d’application lors des réinstallations.
Les renouvellements et migrations ne sont pas annoncés comme testés par cette
validation. Chaque appareil doit être appairé séparément ; aucune synchronisation
automatique de l’historique entre appareils n’est fournie.

## Sécurité

Le code commun utilise X25519, HKDF-SHA256 et AES-256-GCM pour les échanges,
ainsi que PBKDF2-HMAC-SHA256 pour le coffre local. Les clés d’identité Apple sont
conservées dans le Trousseau. Comparer les numéros de sécurité des contacts par
un autre canal. Le relais voit des métadonnées de routage.
TTalk n’a pas été audité indépendamment.

Le statut final décrit le parcours fonctionnel testé ; il ne signifie pas que
les archives GitHub disposent d’une signature de distribution Apple.

## Vérification SHA256

Télécharger chaque archive et son fichier `.sha256` dans le même dossier, puis
exécuter dans Terminal :

```sh
shasum -a 256 -c ttalk-ios-unsigned.ipa.sha256
shasum -a 256 -c ttalk-macos-unsigned.zip.sha256
```

Le résultat doit indiquer `OK` pour chaque fichier.
Ces empreintes vérifient l’intégrité des téléchargements ; elles ne signent
pas les applications pour Apple.

## Documentation

[Installation iPhone et Android](https://github.com/btalal/TTalk/blob/main/ttalk/docs/MOBILE_INSTALL.md) ·
[Installation Mac](https://github.com/btalal/TTalk/blob/main/ttalk/docs/MACOS_INSTALL.md) ·
[Essais sur appareils réels](https://github.com/btalal/TTalk/blob/main/ttalk/docs/APPLE_VALIDATION.md) ·
[Sécurité et limites](https://github.com/btalal/TTalk/blob/main/ttalk/docs/SECURITY.md) ·
[Relais](https://github.com/btalal/TTalk/blob/main/ttalk/server/README.md)

Les anciennes préversions restent conservées comme archives historiques.

Pour signaler un problème, ouvrir une [issue GitHub](https://github.com/btalal/TTalk/issues)
avec le modèle d’appareil et les étapes de reproduction, sans publier de
message privé, code d’appairage ou secret.
