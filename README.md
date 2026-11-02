# TTalk

Messagerie texte **chiffrée de bout en bout**, simple, au format **EXE** pour **Windows 10/11 x64**.

## Comment ça marche

- Chaque appareil génère une paire de clés **X25519**. Deux contacts appairés dérivent
  une clé de session commune (ECDH + **HKDF-SHA256**).
- Chaque message est chiffré en **AES-256-GCM** avec un nonce aléatoire : le relais
  (et toute personne interceptant le réseau) ne voit que des octets illisibles.
- Le stockage local (conversations, messages) est chiffré par un **code PIN**
  (PBKDF2-SHA256, 210 000 itérations, sel aléatoire) via le stockage sécurisé
  de Windows (Gestionnaire d’identifiants / Credential Manager).
- Un **numéro de sécurité** (empreinte SHA-256 des deux clés publiques, ordonnées)
  permet de vérifier hors-bande qu'aucun tiers n'a substitué les clés (anti-MITM).

## Appairage

1. L'un des deux contacts génère un **code à 6 caractères** (affiché dans l'app).
2. L'autre saisit ce code dans « Appairer un contact ».
3. Le relais met les deux appareils en relation et échange leurs clés publiques.
4. Comparez vos numéros de sécurité pour confirmer l'identité de l'autre.

## Structure du dépôt

```
lib/
  crypto/e2e_crypto.dart     # X25519, HKDF, AES-256-GCM, PBKDF2, empreinte
  services/secure_store.dart # stockage chiffré par PIN (Credential Manager Windows)
  services/relay_client.dart # client WebSocket du relais
  state/app_state.dart       # état applicatif
  ui/                        # écrans (déverrouillage, accueil, conversation)
server/relay.js              # relais Node.js (ne voit que du chiffré)
test/e2e_crypto_test.dart    # tests unitaires crypto
```

## Lancer le relais

```bash
cd server
npm install
npm start          # écoute sur ws://127.0.0.1:8080 (PORT=<port> pour changer)
```

> En production, faites tourner le relais derrière **wss://** (TLS) sur un serveur à vous.

## Développer et compiler sous Windows

Prérequis sur une machine **Windows 10/11 x64** :

- Flutter **3.47.9** (version utilisée par la CI).
- Visual Studio 2022 avec la charge de travail **Développement Desktop en C++**
  et le SDK Windows.
- Mode développeur Windows activé pour les liens symboliques des plugins.
- Node.js et npm pour exécuter le relais local.

Depuis la racine du dépôt :

```powershell
flutter doctor -v
flutter pub get --enforce-lockfile
flutter test
flutter run -d windows
flutter build windows --release --target-platform windows-x64
```

L'URL du relais se règle à la compilation :

```powershell
flutter build windows --release --target-platform windows-x64 --dart-define=RELAY_URL=wss://relais.example.com
```

Par défaut, l'application utilise `ws://localhost:8080` : lancez le relais avant
l'application. Pour communiquer entre deux PC, utilisez un relais commun accessible
via `wss://`. Le serveur Node.js écoute uniquement sur l'interface locale ; exposez-le
avec un reverse proxy TLS sur la machine qui l'héberge.

## Accusés de lecture

Comme sur WhatsApp, chaque message envoyé affiche une coche double dans la bulle :
**✓✓ gris** = arrivé chez le destinataire, **✓✓ bleu** = lu. L'accusé est envoyé
automatiquement quand la conversation est ouverte (et à la réception d'un message
si l'écran est ouvert). Le relais ne transporte que l'identifiant du message, jamais son contenu.

## Groupes chiffrés

- Onglet **Groupes** → « groupe + » → choisis un nom et des contacts appairés.
- Une **clé de groupe AES-256** aléatoire est générée ; chaque invité la reçoit
  chiffrée individuellement avec sa clé de session (X25519), via le relais.
- Les messages de groupe sont chiffrés avec la clé de groupe et envoyés à tous
  les membres ; le nom de l'expéditeur est affiché au-dessus de chaque bulle.
- **Gestion des membres** (icône 👥 dans le groupe) :
  - 👑 le créateur est **admin** ; il peut **réinviter/ajouter** un contact et
    **retirer** un membre (la clé de groupe est alors **pivotée** — `epoch+1` —
    pour que le membre retiré ne puisse plus lire les nouveaux messages) ;
  - tout membre peut **quitter** le groupe ; si le dernier admin part, le premier
    membre restant devient admin.

Le propriétaire peut **transférer la propriété** à un membre ayant accepté
l’invitation depuis la liste des membres (bouton « Transférer la propriété »).
Après confirmation, le destinataire devient propriétaire et administrateur ;
l’ancien propriétaire reste membre sans droits d’administration.

À l’acceptation d’une invitation, une notification **« X a rejoint le groupe »**
apparaît dans la conversation des membres connectés. Elle est transmise chiffrée
et conservée dans l’historique local. Une invitation en attente ne déclenche pas
cette notification. Le relais actuel ne met pas les événements hors ligne en attente.
Les participants doivent utiliser une version de TTalk prenant en charge ces événements.

## Pièces jointes chiffrées

- Bouton 📎 dans une conversation : le fichier est chiffré localement en
  **AES-256-GCM** avec une clé aléatoire par fichier ; cette clé est incluse
  dans le message, lui-même chiffré de bout en bout.
- À la réception, le fichier est déchiffré et enregistré dans le dossier
  documents de l'app (`ttalk_files/`) ; un appui l'ouvre.
- Le relais ne voit jamais ni le nom ni le contenu du fichier en clair.

## Télécharger et lancer TTalk

Les [releases GitHub](https://github.com/btalal/TTalk/releases) Windows contiennent
l'archive **`ttalk-windows-x64.zip`**. Extrayez **tout** son contenu, puis lancez
**`ttalk.exe`**. Gardez les DLL et le dossier `data` à côté de l'exécutable :
le fichier EXE seul ne suffit pas.

Le [workflow de release](.github/workflows/release.yml) teste l'application sur
Windows, compile uniquement la cible Windows x64, puis publie le ZIP sur un tag
`vX.Y.Z-windows` après le push d'un tag de version `vX.Y.Z`.
La compilation de l'EXE nécessite Windows et MSVC.

## Limites connues (v0.3)

- Appairage manuel par code (pas de découverte automatique).
- Pas d'appels audio/vidéo.
