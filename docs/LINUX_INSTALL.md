# TTalk 0.6.1 — installation Linux

Deux architectures natives sont proposées :

| Architecture | DEB | RPM |
|---|---|---|
| Intel and AMD x86_64 | `amd64` — Ubuntu 24.04/26.04 et Zorin OS Pro 18.1 | `x86_64` — Fedora 45 |
| ARM® aarch64 | `arm64` — Ubuntu 24.04/26.04 ARM64 | `aarch64` — Fedora 45 ARM64 |

Choisir selon le processeur et le système installé (`uname -m`). Le DEB est
construit sur Ubuntu 24.04 ; Ubuntu 22.04 n’est pas couvert. Zorin OS Pro 18.1
est couvert par le paquet Intel/AMD, sans annonce de version Zorin ARM64.

Le propriétaire confirme l’installation et le fonctionnement général sous Fedora 45
et Zorin OS Pro 18.1 le 8 novembre 2026. Les contrôles automatisés couvrent aussi
Ubuntu 24.04 et 26.04. Voir [le compte rendu](LINUX_VALIDATION.md).

## Installation

Intel/AMD — Ubuntu 24.04/26.04 et Zorin OS 18.1 :

```sh
sudo apt install ./ttalk_0.6.1-4_amd64.deb
```

Intel/AMD — Fedora 45 :

```sh
sudo dnf install ./ttalk-0.6.1-4*.x86_64.rpm
```

ARM® aarch64 — Ubuntu 24.04/26.04 :

```sh
sudo apt install ./ttalk_0.6.1-4_arm64.deb
```

ARM® aarch64 — Fedora 45 :

```sh
sudo dnf install ./ttalk-0.6.1-4*.aarch64.rpm
```

Les paquets sont accompagnés de SHA256, mais ne sont pas signés par une clé GPG
de distribution. Vérifier la provenance et l’empreinte avant installation.
Ne pas contourner globalement les vérifications du gestionnaire de paquets.
Lancer TTalk depuis le menu des applications ou avec `ttalk` dans un terminal.
Ne jamais lancer l’application avec sudo : son coffre appartient à votre session.

## Premier démarrage et sécurité

Se connecter à une session de bureau avec un trousseau Secret Service disponible
et déverrouillé (GNOME Keyring, installé comme dépendance). Une connexion automatique
sans saisie du mot de passe peut laisser le trousseau verrouillé. Le déverrouiller
dans l’outil de gestion du trousseau de votre bureau. Le PIN TTalk ne remplace pas
ce mot de passe. L’application refuse un stockage de remplacement non protégé.

Le choix des fichiers nécessite un portail de bureau actif ; le paquet installe
xdg-desktop-portal et son backend GTK. Sous GNOME/KDE, conserver aussi le backend
prévu par votre distribution et se reconnecter après une première installation.
`xdg-open` sert à ouvrir une pièce jointe dans l’application associée.

Créer un PIN, configurer l'url de votre relais privé, et appairer les
contacts séparément. Chaque installation possède son identité et son historique.
Ni synchronisation automatique avec les autres appareils, ni migration implicite.
Les limites du protocole 0.6.1 restent celles documentées dans NEXT_SECURITY.md.

La biométrie et la caméra QR ne sont pas proposées sur Linux dans cette révision.
Les invitations QR peuvent être affichées ; les codes et liens peuvent être collés.
Aucune notification push n’est ajoutée.

## Données et mises à jour

Le programme et ses bibliothèques résident dans `/usr/lib/ttalk`, avec un lanceur
`/usr/bin/ttalk`. Les préférences sont dans le dossier XDG de l’utilisateur et les
clés dans son trousseau de session. Les mises à jour du paquet ne suppriment pas
ces données ; ne pas effacer le trousseau pour tenter de réparer un démarrage.
Les sauvegardes chiffrées existantes peuvent être restaurées uniquement dans un
coffre vide ; arrêter l’identité d’origine avant de la restaurer sur Linux.

## Vérifications conseillées après installation

Installation, icône de menu, démarrage, seconde instance, redémarrage avec le même
PIN, identité conservée, trousseau verrouillé/absent, messages et fichiers avec
Windows/Android/iPhone/Mac, recherche, sauvegarde/restauration, retrait d’un membre,
verrouillage/suspension, choix et ouverture de fichiers, puis mise à jour du paquet.
Ne rapporter aucun PIN, secret, phrase de passe ou message privé dans les issues.

Sources : [Flutter Linux](https://docs.flutter.dev/platform-integration/linux/setup),
[base de Zorin 18.1](https://zorin.com/os/details/).

## Révision 2 — emojis en couleur

Le propriétaire confirme l’installation et le fonctionnement sous Fedora 45 et
Zorin OS Pro 18.1. Il signale uniquement les symboles/anciens avatars emojis en
noir et blanc ; les portraits dessinés restent en couleur. La révision 2 utilise
explicitement Noto Color Emoji pour ces symboles et installe la police système
(`fonts-noto-color-emoji` sur Ubuntu/Zorin, `google-noto-color-emoji-fonts` sur Fedora).
Installer le nouveau paquet avec apt/dnf par-dessus le précédent, puis fermer et
rouvrir TTalk. Ne pas désinstaller et ne pas supprimer le coffre ni le trousseau.
La mise à jour conserve contacts, historique et choix d’icônes.

## Révision 3 — documentation du relais

Les guides utilisent désormais l'url de votre relais privé au lieu d’une adresse personnelle.
Le protocole, le coffre et les emojis couleur sont inchangés. Installer la révision 3
par-dessus la précédente sans désinstaller TTalk.

## Révision 4 — icônes couleur

24 icônes supplémentaires pour les profils et les groupes, identiques sur toutes
les plateformes. Choisir une icône dans « Nom et icône ». Les anciens avatars et
emojis restent disponibles et les choix existants sont conservés.
