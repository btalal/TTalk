# TTalk 0.6.1 — portage Linux en validation

Premiers paquets x86_64 (Intel/AMD 64 bits) : DEB construit sur Ubuntu 24.04 LTS,
également cible de base pour Zorin OS Pro 18.1 ; installation testée aussi sous
Ubuntu 26.04. RPM pour Fedora 45.
Ubuntu 22.04 et les machines ARM64 ne sont pas annoncés compatibles avec ce lot.
Les essais automatiques en conteneur ne remplacent pas des essais sur les bureaux
réels Fedora et Zorin (Wayland/X11, fichiers, verrouillage et échanges).

## Installation

Ubuntu 24.04 et Zorin OS 18.1 :

```sh
sudo apt install ./ttalk_0.6.1-1_amd64.deb
```

Fedora 45 :

```sh
sudo dnf install ./ttalk-0.6.1-1*.x86_64.rpm
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

Créer un PIN, configurer `https://ttalk.fly.dev` ou votre relais, et appairer les
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

## Validation à effectuer sur vos machines

Installation, icône de menu, démarrage, seconde instance, redémarrage avec le même
PIN, identité conservée, trousseau verrouillé/absent, messages et fichiers avec
Windows/Android/iPhone/Mac, recherche, sauvegarde/restauration, retrait d’un membre,
verrouillage/suspension, choix et ouverture de fichiers, puis mise à jour du paquet.
Ne rapporter aucun PIN, secret, phrase de passe ou message privé dans les issues.

Sources : [Flutter Linux](https://docs.flutter.dev/platform-integration/linux/setup),
[base de Zorin 18.1](https://zorin.com/os/details/).
