# 🔒 TTalk 0.6.1 — iPhone et macOS

🟢 **Version finale — iOS 15+ et macOS 12+ (paquets non signés)**

## Téléchargements

- [ttalk-ios-unsigned.ipa](https://github.com/btalal/TTalk/releases/download/v0.6.1-apple/ttalk-ios-unsigned.ipa) — à signer avec votre compte développeur (voir INSTALLATION.md)
- [ttalk-macos-unsigned.zip](https://github.com/btalal/TTalk/releases/download/v0.6.1-apple/ttalk-macos-unsigned.zip) — voir MACOS_INSTALL.md
- [Sommes SHA256](https://github.com/btalal/TTalk/releases/download/v0.6.1-apple/SHA256SUMS.txt)

Mise à jour : conservez l’identifiant de l’application pour garder vos données ; ne désinstallez pas.

## Nouveautés de la 0.6.1 — nouvelle interface

- **Même interface sur Windows, Mac, Android et iPhone** : menu Discussions, Contacts et Réglages en bas de l’écran, y compris en fenêtre agrandie.
- **En-tête** : logo TTalk, numéro de version et badge « Connecté ». Le bandeau du serveur n’apparaît plus qu’en cas de problème ou d’envois en attente.
- **Avatars illustrés** : 20 pour les contacts et 20 pour les groupes, à choisir dans « Nom et icône ». Sans choix, chaque contact reçoit automatiquement une illustration, la même sur tous ses appareils. Les emojis déjà choisis sont conservés.
- **Contacts vérifiés** signalés par une pastille verte.
- **Liste** : filtres sur une seule ligne, conversations non lues en gras avec leur nombre de messages.
- **Discussion** : nouvelles bulles, dates en pastille, zone de saisie arrondie.
- **Police Inter** intégrée pour un affichage identique partout.
- **Bureau** : fenêtre de 800 × 600 au démarrage, titre « Messagerie chiffrée & gratuite », barre de titre neutre.

Aucune modification du chiffrement ni du relais : la 0.6.1 échange normalement avec les appareils en 0.6.0.

## Rappel des nouveautés de la 0.6

Recherche locale, filtres, conversations épinglées et archivées ; invitations par QR code ou lien ; réponses citées et réactions chiffrées ; verrouillage manuel et automatique ; sauvegarde locale chiffrée.

## Sécurité

X25519, HKDF-SHA256 et AES-256-GCM ; coffre local protégé par PIN. Comparez les numéros de sécurité de vos contacts par un autre canal. TTalk n’a pas fait l’objet d’un audit indépendant. Les notifications mobiles ne sont pas encore disponibles.

Signalez les problèmes dans les issues, sans publier de PIN, de clé ni de contenu privé.


## Version Linux

[TTalk 0.6.1 pour Linux — RPM Fedora 45 et DEB Ubuntu/Zorin](https://github.com/btalal/TTalk/releases/tag/v0.6.1-linux), disponible en Intel/AMD 64 bits. Les paquets Linux sont distincts des téléchargements ci-dessus.
