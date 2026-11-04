<p align="center">
  <img src="assets/branding/ttalk.png" width="180" height="180" alt="Logo TTalk : deux bulles bleu nuit et violet, avec un cadenas ivoire" />
</p>

<h1 align="center">TTalk</h1>

<p align="center">
  Une messagerie texte simple, <strong>chiffrée de bout en bout</strong>, pour vos conversations privées.
</p>

Deux bulles pour la conversation, un cadenas pour la confidentialité : l’identité
visuelle de TTalk associe le bleu nuit, l’indigo et le violet. Cette même identité
accompagne les versions pour ordinateur et téléphone.

## Windows 10/11 x64

La version finale Windows **0.5.1** est une application de bureau
au format **EXE**, distribuée dans une archive ZIP. Son icône permet de repérer
le lanceur `TTalk.exe` ; elle apparaît également sur l’écran de déverrouillage.
Un code PIN protège le coffre local et les clés de l’appareil sont conservées
dans le stockage sécurisé de Windows.

## Android 7.0+ — version finale 0.5.1

La version Android propose une interface adaptée au téléphone. Chaque appareil
possède sa propre identité, conservée dans le **Keystore Android**, et s’appaire
séparément avec ses contacts.

L’installation utilise **`ttalk-android.apk`**, le package signé de la release Android.
Les modalités sont détaillées dans
le [guide mobile](docs/MOBILE_INSTALL.md).

## iPhone sous iOS 15+ — préversion 0.5

La préversion iOS adapte TTalk à l’iPhone et conserve l’identité de l’appareil
dans le **Trousseau iOS**. Chaque iPhone s’appaire séparément avec ses contacts.

Sur un Mac récent, Xcode peut signer et installer la préversion directement sur
un iPhone avec un compte Apple gratuit. Un IPA non signé est aussi produit par
la CI pour une signature personnelle. Voir le [guide mobile](docs/MOBILE_INSTALL.md).

## Nouveautés Windows et Android 0.5.1

Les menus **⋮** permettent de supprimer un message, une conversation ou un contact,
d’effacer l’historique d’un groupe, ou de le quitter et le supprimer localement.
L’onglet **Contacts** conserve les contacts après suppression de leur conversation.
Les noms et vingt icônes intégrées sont personnalisables sur chaque appareil.
Les suppressions demandent confirmation et conservent les copies des autres
participants ainsi que les fichiers déjà enregistrés.

Cette version corrige aussi plusieurs erreurs d’appairage, de profil, de formulaires
et d’envoi. Consulter le [guide des nouveaux menus](docs/CHAT_MANAGEMENT.md).

## Compatibilité et limites mobiles

Android et iOS partagent le protocole chiffré de **Windows 0.4** et utilisent
le **même relais** pour échanger entre les appareils.

Les archives de compilation non signées **ne s’installent pas directement**.
Sur mobile, les notifications push et la réception permanente en arrière-plan
ne sont pas encore intégrées : la réception reprend à l’ouverture de l’application.
Les échanges Windows/Android ont été validés sur deux PC Windows x64 et un
smartphone Android : messages, fichiers, redémarrage, réception différée, groupes
et transfert de propriété. iPhone reste en préversion et à valider sur appareil réel.

## Comment ça marche

- Chaque appareil génère une paire de clés **X25519**. Deux contacts appairés dérivent
  une clé de session commune (ECDH + **HKDF-SHA256**).
- Chaque message est chiffré en **AES-256-GCM** avec un nonce aléatoire : le relais
  (et toute personne interceptant le réseau) ne voit que des octets illisibles.
- Le stockage local (conversations, messages) est chiffré par un **code PIN**
  (PBKDF2-SHA256, 210 000 itérations, sel aléatoire) via le stockage sécurisé
  de Windows, Android ou iOS selon l’appareil.
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
  services/secure_store.dart # stockage chiffré par PIN (stockage sécurisé Windows)
  services/relay_client.dart # client WebSocket du relais
  state/app_state.dart       # état applicatif
  ui/                        # écrans (déverrouillage, accueil, conversation)
server/relay.js              # relais Node.js (ne voit que du chiffré)
test/e2e_crypto_test.dart    # tests unitaires crypto
```

## Utiliser Windows 0.5.1

1. Extraire tout le ZIP Windows x64, puis lancer **`TTalk.exe`** à la racine.
2. Créer ou saisir son PIN. Les données existantes sont conservées.
3. Ouvrir **Configurer le serveur** et saisir `https://ttalk.fly.dev`.
   Les deux PC doivent utiliser la même adresse. Aucune recompilation n’est nécessaire.
4. Choisir **Mon nom**, puis échanger un code d’appairage et comparer les numéros
   de sécurité par un autre canal.

L’adresse n’est pas préconfigurée : chaque nouvel appareil doit utiliser le même
relais. La configuration et le déploiement du serveur sont décrits dans
[server/README.md](server/README.md).

Les identifiants sont désormais liés aux clés persistantes des appareils.
Les contacts restent valables après redémarrage. Les envois sans réseau sont
conservés dans le coffre chiffré ; le relais garde les paquets destinés aux
appareils absents jusqu’à leur confirmation, pendant **7 jours maximum**.
La reconnexion et les reprises d’envoi sont automatiques.

Une horloge indique un envoi en attente d’acceptation par le serveur ; une coche
indique son acceptation, deux coches son arrivée, et les coches bleues sa lecture.
Une acceptation ne garantit pas une livraison après l’expiration du délai de 7 jours.

### Migration depuis 0.3.6

Le PIN, les clés, les conversations et l’historique sont conservés. Les anciens
identifiants de contacts sont convertis à partir de leurs clés publiques.
Les groupes utilisant les anciens IDs restent consultables en historique, mais
**doivent être recréés**. Les applications 0.4 et le nouveau relais doivent être
utilisés ensemble : le relais 0.3.6 n’est pas compatible avec cette version.

## Développer et compiler sous Windows

Prérequis : Flutter **3.47.9**, Visual Studio 2022 avec « Développement Desktop en
C++ » et le SDK Windows, mode développeur activé. Node.js **24** est nécessaire
pour développer et tester le relais, pas pour exécuter l’application avec un relais hébergé.

```powershell
flutter doctor -v
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter run -d windows
flutter build windows --release
```

Le runner Windows x64, CMake et le contrôle des fichiers PE garantissent la cible
x64. Le [relais](server/README.md) se lance avec `npm ci` puis `npm start` depuis
`server`. Pour un test local, saisir `http://localhost:8080` dans l’application.
Une adresse distante doit utiliser HTTPS/WSS.

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
    pour envoyer les nouveaux messages uniquement aux membres restants) ;
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
- Les pièces jointes sont limitées à **5 Mo**. Les fichiers reçus sont déchiffrés
  dans Documents et ne sont plus chiffrés une fois enregistrés sur disque.

## Télécharger et lancer TTalk

Les [releases GitHub](https://github.com/btalal/TTalk/releases) Windows contiennent
l'archive **`ttalk-windows-x64.zip`**. Extrayez **tout** son contenu, puis lancez
**`TTalk.exe`**, visible à la racine :

```text
TTalk.exe       ← double-cliquer pour démarrer (icône TTalk)
LIRE-MOI.txt    ← instructions
app/           ← application, DLL et données techniques
```

Conservez le dossier `app` à côté de `TTalk.exe`. Vous pouvez créer un raccourci
vers `TTalk.exe` sur le Bureau ; il fonctionne quel que soit le dossier de départ.
Le lanceur n’affiche pas de console et ne nécessite pas d’installation.

Le package inclut les DLL du runtime MSVC x64. Une somme **SHA256** accompagne
le ZIP. La CI contrôle son contenu et ouvre l’application extraite sans relais
avant publication.

Le [workflow de release](.github/workflows/release.yml) teste l'application sur
Windows, compile uniquement la cible Windows x64, puis publie le ZIP sur un tag
`vX.Y.Z-windows` après le push d'un tag de version `vX.Y.Z`.
La compilation de l'EXE nécessite Windows et MSVC.

## Limites connues

- Appairage manuel par code (pas de découverte automatique).
- Pas d'appels audio/vidéo.
- Les notifications mobiles sont reportées ; la réception reprend à l’ouverture
  de l’application.
- Un accusé chiffré signale l’ouverture de la conversation par l’application ;
  il ne prouve pas qu’une personne a effectivement lu le texte.
