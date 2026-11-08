# 🔒 TTalk 0.6.1 — Windows x64 et ARM64

🟢 **Version finale — Intel/AMD x86_64 et ARM64**

## Téléchargements

### Intel and AMD x86_64 — Windows 10/11

- [ttalk-windows-x64.zip](https://github.com/btalal/TTalk/releases/download/v0.6.1-windows/ttalk-windows-x64.zip) — extraire tout le dossier puis lancer `TTalk.exe` (voir `LISEZ-MOI.txt`)
- [Empreinte SHA-256](https://github.com/btalal/TTalk/releases/download/v0.6.1-windows/ttalk-windows-x64.zip.sha256)

### ARM® aarch64 — Windows 11 ARM64

- [ttalk-windows-arm64.zip](https://github.com/btalal/TTalk/releases/download/v0.6.1-windows/ttalk-windows-arm64.zip) — extraire tout le dossier et lancer `TTalk.exe`
- [Empreinte SHA-256 ARM64](https://github.com/btalal/TTalk/releases/download/v0.6.1-windows/ttalk-windows-arm64.zip.sha256)

Choisir le ZIP correspondant à votre processeur dans **Paramètres > Système > Informations système**.
Le paquet ARM64 contient un exécutable, un moteur Flutter et des DLL natifs ARM64.

Mise à jour : fermez TTalk, remplacez l’ancien dossier par le nouveau. Vos contacts, messages et PIN sont conservés.
Le paquet n’est pas signé Authenticode : Windows peut afficher un avertissement au premier lancement.

## Nouveautés de la 0.6.1 — nouvelle interface

- **24 nouvelles icônes couleur** pour les profils et les groupes : appareils, lieux, systèmes, fabricants et distributions Linux. Sélection dans « Nom et icône » ; anciens choix conservés.

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

[TTalk 0.6.1 pour Linux — RPM Fedora 45 et DEB Ubuntu/Zorin](https://github.com/btalal/TTalk/releases/tag/v0.6.1-linux-r4), disponible en Intel and AMD x86_64 et ARM® aarch64. Les paquets Linux sont distincts des téléchargements ci-dessus.
