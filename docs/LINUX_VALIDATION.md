# Validation Linux — TTalk 0.6.1, paquets révision 3

## Essais rapportés par le propriétaire — 8 novembre 2026

Installation des premiers DEB/RPM et fonctionnement général confirmés sous
Fedora 45 et Zorin OS Pro 18.1, sur Intel/AMD 64 bits. Un défaut est signalé :
les anciens symboles/avatars emojis sont monochromes, tandis que les portraits
dessinés par TTalk sont correctement colorés. La révision 2 corrige le choix de
police et déclare la dépendance Noto Color Emoji. Les variantes de bureau,
le serveur graphique et les modèles de GPU de ces postes ne sont pas précisés.

## Contrôles automatiques de la révision 2

[Workflow et artefacts](https://github.com/btalal/TTalk/actions/runs/42487295184) :
analyse Dart propre, 83 tests Flutter, compilation Linux Release et test natif du
trousseau réel (identité conservée, PIN, verrouillage et navigation).
Installation, démarrage, seconde instance et désinstallation validés sous Ubuntu
24.04, Ubuntu 26.04 et Fedora 45. Un programme de contrôle séparé utilise le même
widget EmojiSymbol et le moteur natif : il vérifie les pixels colorés d’un emoji
sur les trois distributions et enregistre une capture. Le contrôle Fedora compte
5 903 pixels colorés. Ce programme de contrôle n’est pas inclus dans TTalk.

## Portée et limites

Les nouveaux paquets contiennent le même protocole 0.6.1 que les autres plateformes.
Aucun audit cryptographique ni qualification de toutes les configurations Linux
n’est annoncé. La biométrie et le scanner QR par caméra restent indisponibles.
Les paquets sont accompagnés de SHA256, sans signature GPG de distribution.
Les essais matériels de la révision 2 et l’extension des scénarios fichiers,
interruptions, suspension et trousseau verrouillé restent utiles après mise à jour.

## Extension ARM® aarch64

Compilation native sur Ubuntu 24.04 ARM64 ; DEB `arm64` et RPM `aarch64`
assemblés avec les outils natifs de chaque distribution. La chaîne vérifie
l’architecture ELF de l’exécutable et de toutes les bibliothèques incluses.
Les mêmes contrôles du trousseau réel, du démarrage, de l’instance unique,
de la désinstallation et du rendu couleur sont exécutés sur ARM64 sous Ubuntu
24.04, Ubuntu 26.04 et Fedora 45. Les essais manuels du propriétaire décrits
ci-dessus concernent uniquement Intel/AMD x86_64 ; aucun essai matériel ARM
n’est attribué au propriétaire. Zorin est couvert uniquement en amd64.

La révision 3 retire aussi l’adresse personnelle du relais des guides intégrés.
