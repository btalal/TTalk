# TTalk

Messagerie texte **chiffrée de bout en bout**, simple, pour **Android** et **Windows**.

## Comment ça marche

- Chaque appareil génère une paire de clés **X25519**. Deux contacts appairés dérivent
  une clé de session commune (ECDH + **HKDF-SHA256**).
- Chaque message est chiffré en **AES-256-GCM** avec un nonce aléatoire : le relais
  (et toute personne interceptant le réseau) ne voit que des octets illisibles.
- Le stockage local (conversations, messages) est chiffré par un **code PIN**
  (PBKDF2-SHA256, 210 000 itérations, sel aléatoire) via le stockage sécurisé
  de l'OS (Keystore Android / Credential Manager Windows).
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
  services/secure_store.dart # stockage chiffré par PIN (Keystore/Credential Manager)
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

## Compiler l'application

Prérequis : [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable).

```bash
flutter pub get
flutter test                       # tests crypto
flutter run -d android             # Android (téléphone connecté ou émulateur)
flutter run -d windows             # Windows (mode développeur activé)
```

L'URL du relais se règle à la compilation :

```bash
flutter run -d android --dart-define=RELAY_URL=wss://relais.example.com
```

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

## Pièces jointes chiffrées

- Bouton 📎 dans une conversation : le fichier est chiffré localement en
  **AES-256-GCM** avec une clé aléatoire par fichier ; cette clé est incluse
  dans le message, lui-même chiffré de bout en bout.
- À la réception, le fichier est déchiffré et enregistré dans le dossier
  documents de l'app (`ttalk_files/`) ; un appui l'ouvre.
- Le relais ne voit jamais ni le nom ni le contenu du fichier en clair.

## Binaires

| Plateforme | Comment obtenir le binaire |
|---|---|
| **Android (APK)** | [Release GitHub](https://github.com/btalal/Talmessenger/releases) (asset `ttalk-*-signed.apk`, arm64), ou `flutter build apk --release` |
| **Windows x64 (EXE)** | artefact `ttalk-windows-x64` produit par la [CI GitHub Actions](.github/workflows/release.yml) (`flutter build windows --release` sur `windows-latest`), ou localement sur Windows : `flutter build windows --release` |

> Un exécutable Windows x64 nécessite impérativement le toolchain MSVC d'une machine
> Windows — c'est pourquoi la CI `windows-latest` le produit. L'APK arm64 signé est
> livré en release ; installe-le sur Android via « sources inconnues ».

## Limites connues (v0.3)

- Appairage manuel par code (pas de découverte automatique).
- Groupes : pas de transfert de propriété du groupe, pas de notification « X a rejoint ».
- Pas d'appels audio/vidéo.
