# Développer TTalk

## Structure du dépôt

```text
lib/crypto/e2e_crypto.dart      X25519, HKDF, AES-GCM et dérivation du PIN
lib/services/secure_store.dart  coffre local et stockage sécurisé
lib/services/relay_client.dart  connexion WebSocket au relais
lib/state/app_state.dart        état applicatif
lib/ui/                       écrans Flutter
server/relay.js                relais Node.js
test/                          tests Flutter
```

## Compiler sous Windows

Prérequis : Flutter **3.47.9**, Visual Studio 2022 avec le développement
Desktop en C++, SDK Windows et mode développeur. Node.js **24** sert au
développement du relais ; il n’est pas nécessaire pour exécuter un client
connecté à un relais hébergé.

```powershell
flutter doctor -v
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter run -d windows
flutter build windows --release
```

Le [relais](../server/README.md) se lance depuis `server` avec `npm ci`,
`npm test` et `npm start`. Le [workflow de release](../.github/workflows/release.yml)
construit l’archive Windows x64 et la publie avec ses contrôles d’intégrité.

## Migration depuis 0.3.6

Le PIN, les clés, les conversations et l’historique sont conservés. Les anciens
identifiants de contacts sont convertis à partir des clés publiques. Les groupes
utilisant les anciens identifiants restent consultables dans l’historique, mais
**doivent être recréés**. Les applications 0.4 et ultérieures nécessitent le
nouveau relais : celui de 0.3.6 n’est pas compatible.

## Limites et pistes de développement

- Pas d’appels audio ou vidéo ; l’appairage reste manuel.
- Pas encore de notifications push ni de réception mobile permanente en
  arrière-plan.
- Les conversations directes n’utilisent pas de ratchet ; la confidentialité
  future des groupes après retrait d’un membre dépend encore du relais.
- Les versions finales iPhone et macOS sont validées pour la signature
  personnelle Xcode en Release, sur iPhone 17 Pro (iOS 27.2) et Mac mini M4.
  Les archives CI restent non signées. Voir [les essais](APPLE_VALIDATION.md)
  avant de généraliser ces résultats à d’autres appareils ou scénarios.

Lire les [revues techniques](PROJECT_REVIEW.md) et le [modèle de sécurité](SECURITY.md)
avant de modifier le protocole.
