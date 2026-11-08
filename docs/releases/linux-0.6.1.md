# 🔒 TTalk 0.6.1 — Linux x86_64

🟢 **Version finale — RPM et DEB, révision 3**

## Téléchargements

- 🐧 [RPM Fedora 45](https://github.com/btalal/TTalk/releases/download/v0.6.1-linux/ttalk-0.6.1-3.fc45.x86_64.rpm)
- 🔐 [SHA256 du RPM](https://github.com/btalal/TTalk/releases/download/v0.6.1-linux/ttalk-0.6.1-3.fc45.x86_64.rpm.sha256)
- 📦 [DEB Ubuntu 24.04/26.04 et Zorin OS Pro 18.1](https://github.com/btalal/TTalk/releases/download/v0.6.1-linux/ttalk_0.6.1-3_amd64.deb)
- 🔐 [SHA256 du DEB](https://github.com/btalal/TTalk/releases/download/v0.6.1-linux/ttalk_0.6.1-3_amd64.deb.sha256)
- 📖 [Installation et mise à jour](https://github.com/btalal/TTalk/releases/download/v0.6.1-linux/INSTALLATION.md)

## Pour qui ?

Pour les utilisateurs de PC Intel/AMD 64 bits sous Fedora 45, Ubuntu 24.04/26.04
et Zorin OS Pro 18.1. Ubuntu 22.04 et ARM64 ne sont pas couverts par ces paquets.
Aucun abonnement ni compilation locale n’est nécessaire pour installer ces RPM/DEB.

## Nouveautés

- Application Flutter native Linux avec la même interface 0.6.1 que les autres plateformes.
- Discussions, contacts, groupes, recherche locale, filtres, épinglage et archives.
- Réponses citées, réactions chiffrées et invitations par code ou lien à coller.
- Coffre protégé par PIN et trousseau Secret Service, verrouillage manuel/automatique,
  sauvegarde chiffrée à phrase de passe indépendante et restauration dans un coffre vide.
- Intégration au menu d’applications avec icône, fenêtre 800×600 et instance unique.

## Corrections

- Révision 3 : retrait de l’adresse du relais privé des guides intégrés aux paquets.
  Aucun changement du protocole, des données ni du rendu des emojis.

- Révision 2 : les symboles/avatars emojis utilisent explicitement Noto Color Emoji ;
  la police couleur est installée automatiquement comme dépendance.
- Bibliothèques chargées depuis le dossier de l’application, sans chemin du serveur de compilation.
- Écran de récupération si le coffre ou le trousseau n’est pas accessible, sans stockage de remplacement en clair.

## Compatibilité et validation

| Plateforme | État |
|---|---|
| Fedora 45 x86_64 | Installation et fonctionnement rapportés par le propriétaire ; installation/démarrage/désinstallation et rendu couleur vérifiés automatiquement |
| Zorin OS Pro 18.1 amd64 | Installation et fonctionnement rapportés par le propriétaire ; même base Ubuntu 24.04 que le DEB construit |
| Ubuntu 24.04 et 26.04 amd64 | Installation/démarrage/désinstallation et rendu couleur vérifiés en environnement de test |

Analyse Dart, 83 tests Flutter et test natif du trousseau réussis. Les tests
incluent la persistance d’identité, le PIN, le verrouillage et la navigation.
Le rendu réel des emojis est contrôlé par pixels sur les trois distributions.
Les essais de la révision 2 sur toutes les variantes de bureau/GPU ne sont pas annoncés.
La biométrie, le scanner QR par caméra et les notifications push ne sont pas intégrés sur Linux.

## Mise à niveau et installation

Fermer TTalk, puis installer le nouveau paquet par-dessus la version précédente,
**sans désinstaller**, afin de conserver le coffre, les contacts et les messages.

Ubuntu/Zorin :

```sh
sudo apt install ./ttalk_0.6.1-3_amd64.deb
```

Fedora :

```sh
sudo dnf install ./ttalk-0.6.1-3.fc45.x86_64.rpm
```

Lancer TTalk depuis le menu, sans sudo. Le trousseau de session doit être disponible
et déverrouillé. Configurer l'url de votre relais privé (HTTPS) et appairer
chaque appareil séparément. Les historiques ne sont pas synchronisés automatiquement.
La restauration d’une identité exige d’arrêter son utilisation sur l’appareil d’origine.

## Sécurité

Le protocole reste celui de TTalk 0.6.1 : X25519, HKDF-SHA256 et AES-256-GCM.
Comparer les numéros de sécurité des contacts par un autre canal. Le relais voit
des métadonnées de routage. TTalk n’a pas été audité indépendamment. Double Ratchet
et la refonte des époques de groupe sont planifiés pour une prochaine révision.
Les fichiers déjà déchiffrés hors du coffre ne sont pas effacés par le verrouillage.

## Vérification SHA256

Avant l’installation, comparer le paquet à son fichier `.sha256` :

```sh
sha256sum -c ttalk_0.6.1-3_amd64.deb.sha256
# ou
sha256sum -c ttalk-0.6.1-3.fc45.x86_64.rpm.sha256
```

Le résultat doit être `OK`. Les paquets ne portent pas de signature GPG de distribution ;
les empreintes vérifient leur intégrité, sans remplacer une signature ni un audit.

## Documentation

[Guide Linux](https://github.com/btalal/TTalk/blob/main/ttalk/docs/LINUX_INSTALL.md) ·
[Validation Linux](https://github.com/btalal/TTalk/blob/main/ttalk/docs/LINUX_VALIDATION.md) ·
[Sécurité et limites](https://github.com/btalal/TTalk/blob/main/ttalk/docs/NEXT_SECURITY.md) ·
[Autres plateformes](https://github.com/btalal/TTalk/releases)

Signaler les problèmes dans les issues sans publier de PIN, clé ou contenu privé.
