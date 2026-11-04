# TTalk 0.5 — première préversion mobile

Android et iOS utilisent le même relais **0.4 / protocole 2** que Windows
0.4.0-rc.4. Chaque téléphone possède sa propre identité : appairer chaque appareil
séparément, saisir le même serveur HTTPS, puis comparer les numéros de sécurité.
L’hébergement du relais reste à créer ; aucune adresse n’est préconfigurée.

## Android — APK

Android **7.0 minimum (API 24)**. Le package universel inclut ARM64, ARMv7 et x86_64.
Une fois l’APK signé reçu sur le téléphone, autoriser son installation depuis le
navigateur ou l’application Fichiers, puis installer TTalk. Aucun accès aux contacts,
à la caméra ou à la localisation n’est demandé. Le sélecteur de documents sert
aux pièces jointes. Les captures d’écran sont désactivées sur Android.

**`ttalk-android-unsigned.apk` est un résultat de compilation, pas un APK
installable directement.** Une signature avec une clé persistante est nécessaire.
Les clés privées ne sont jamais publiées dans le dépôt ou les artefacts CI.
La première livraison signée peut être fournie séparément du résultat CI.

Pour une mise à jour conservant le coffre, garder **le même identifiant Android
et la même clé de signature**. Ne pas désinstaller l’application pour forcer une
mise à jour : la désinstallation supprime ses données. Ne pas remplacer une clé
perdue par une nouvelle sans prévenir les utilisateurs.

Compilation avec votre clé (variables d’environnement, ne pas versionner leurs valeurs) :

```sh
flutter pub get --enforce-lockfile
flutter build apk --release
```

Fournir `TTALK_ANDROID_KEYSTORE` (chemin absolu), `TTALK_ANDROID_STORE_PASSWORD`,
`TTALK_ANDROID_KEY_ALIAS` et `TTALK_ANDROID_KEY_PASSWORD` pour produire directement
un APK signé. Sans ces variables, la CI produit volontairement un APK non signé.
Une autre possibilité est `zipalign` puis `apksigner sign` des Android Build Tools,
suivi de `apksigner verify --verbose`.

## iPhone — sans Mac et sans abonnement Apple Developer

iOS **15 minimum**. La CI compile sur un Mac GitHub et prépare
`ttalk-ios-unsigned.ipa`. Ce fichier **n’est pas directement installable** : Apple
exige une signature et un profil d’installation.

Une piste pour un test personnel depuis Windows est [Sideloadly](https://sideloadly.io/) :

1. Installer l’outil depuis son site officiel et suivre ses prérequis Apple sous Windows.
2. Connecter et autoriser l’iPhone, puis ouvrir l’IPA dans l’outil.
3. Effectuer la signature et l’installation avec votre propre compte Apple.
   Ne communiquer aucun identifiant Apple dans ce dépôt ou à l’assistant.
4. Si iOS le demande, approuver le profil dans Réglages et activer le mode
   développeur selon les instructions d’iOS et de l’outil.

Avec un compte gratuit, la signature est généralement limitée à **7 jours** et
le nombre d’applications à installer est limité par Apple. Renouveler la signature
avec le même compte et le même identifiant d’application pour conserver les données.
Cette installation reste à valider sur un véritable iPhone : ce n’est ni une
publication App Store ni une livraison TestFlight.

Une distribution TestFlight ou App Store nécessitera un abonnement Apple Developer,
la configuration de la signature et une validation des règles Apple. Pour compiler
sur son propre Mac : `flutter build ios --release --no-codesign`, puis ouvrir
`ios/Runner.xcworkspace` dans Xcode et configurer sa signature personnelle.

## Fonctionnement et limites à tester

- Messages directs, groupes, transfert de propriété, événements d’arrivée, accusés
  chiffrés et pièces jointes de 5 Mo utilisent le code commun Windows/mobile.
- Sur mobile, la réception est prévue **application ouverte**. Pas de notifications
  push ni de connexion permanente garantie quand l’application est en arrière-plan,
  fermée ou le téléphone verrouillé. La reconnexion reprend au retour dans l’app.
- Les messages restent en attente dans le relais jusqu’à 7 jours : cette file
  serveur ne remplace pas les notifications APNs/FCM, qui ne sont pas intégrées.
- Un écran de confidentialité masque l’interface quand elle devient inactive ;
  il ne remplace pas le verrouillage de l’appareil ni une nouvelle demande de PIN.
- Les clés sont conservées dans le Keystore Android / Trousseau iOS. Les sauvegardes
  Android sont désactivées pour éviter de restaurer un coffre sans ses clés.
- Les fichiers reçus sont déchiffrés dans le dossier privé de l’application mobile.
  Leur ouverture dans une autre application peut créer des copies en clair.
- Une adresse distante, y compris sur le réseau local, doit utiliser HTTPS/WSS avec
  un certificat reconnu. Aucun contournement des certificats n’est activé.
- Tester les échanges Windows ↔ Android ↔ iPhone, le redémarrage, la perte de réseau,
  le retour depuis l’arrière-plan et les mises à jour avant un usage réel.

Les compilations et les tests sur émulateur/simulateur ne prouvent pas à eux seuls
le bon fonctionnement sur tous les téléphones. Le relais et les limites des groupes
restent ceux de la préversion Windows, décrits dans `docs/WINDOWS_READINESS.md`.
