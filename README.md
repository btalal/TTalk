# TalMessenger

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

## Limites connues (v0.2)

- Appairage manuel par code (pas de découverte automatique).
- Pas de pièces jointes ni d'appels — texte uniquement.
- Une seule conversation par contact ; pas de groupes.
