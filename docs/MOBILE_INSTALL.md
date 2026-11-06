# TTalk 0.5.1 — versions finales Android et iPhone

Android et iOS utilisent le même relais **0.4 / protocole 2** que Windows
0.4 / 0.5.1. Chaque téléphone possède sa propre identité : appairer chaque appareil
séparément, saisir le même serveur HTTPS, puis comparer les numéros de sécurité.
Le relais utilisé lors des essais est `https://ttalk.fly.dev` ; saisir cette
adresse dans **Configurer le serveur**, ou celle de votre propre relais HTTPS.
Aucune adresse n’est préconfigurée.

## Android 0.5.1 — APK signé (version finale)

Android **7.0 minimum (API 24)**. Le package universel inclut ARM64, ARMv7 et x86_64.
Une fois l’APK signé reçu sur le téléphone, autoriser son installation depuis le
navigateur ou l’application Fichiers, puis installer TTalk. Aucun accès aux contacts,
à la caméra ou à la localisation n’est demandé. Le sélecteur de documents sert
aux pièces jointes. Les captures d’écran sont désactivées sur Android.

Télécharger **`ttalk-android.apk`**, le package signé prêt à installer, et son
fichier `.sha256` depuis la release mobile. La signature est vérifiée avant
publication ; la clé privée est conservée hors de GitHub.

`ttalk-android-unsigned.apk` reste disponible comme résultat de compilation :
**cette archive non signée ne s’installe pas directement**. Pour les mises à jour,
utiliser le package signé `ttalk-android.apk`.

Pour une mise à jour conservant le coffre, garder **le même identifiant Android
et la même clé de signature**. Ne pas désinstaller l’application pour forcer une
mise à jour : la désinstallation supprime ses données. Ne pas remplacer une clé
perdue par une nouvelle sans prévenir les utilisateurs.

Compilation : Flutter 3.47.9, JDK 21, SDK Android 36 et NDK 29.0.14206865.

Avec votre clé (variables d’environnement, ne pas versionner leurs valeurs) :

```sh
flutter pub get --enforce-lockfile
flutter build apk --release
```

Fournir `TTALK_ANDROID_KEYSTORE` (chemin absolu), `TTALK_ANDROID_STORE_PASSWORD`,
`TTALK_ANDROID_KEY_ALIAS` et `TTALK_ANDROID_KEY_PASSWORD` pour produire directement
un APK signé. Sans ces variables, la CI produit volontairement un APK non signé.
Une autre possibilité est `zipalign` puis `apksigner sign` des Android Build Tools,
suivi de `apksigner verify --verbose`.

## iPhone — version finale, installation personnelle via Xcode

iOS **15 minimum**. Parcours validé le **6 novembre 2026** sur **iPhone 17 Pro
sous iOS 27.2**, avec un Mac mini M4, Xcode 27.2, Flutter 3.47.9 et CocoaPods
1.17.0. Installation, lancement autonome, serveur, contact et messages sont
confirmés dans le [compte rendu](APPLE_VALIDATION.md).

1. Installer Xcode depuis l’App Store, l’ouvrir et accepter la licence et les
   composants de premier lancement. Sélectionner Xcode complet :

   ```sh
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```

2. Installer Flutter **3.47.9 ARM64** et CocoaPods. Si Homebrew est utilisé,
   `brew install cocoapods` l’installe. Ajouter `/opt/homebrew/bin` et le dossier
   `bin` de Flutter au PATH dans `~/.zprofile`. Vérifier `flutter --version`,
   `pod --version` et `flutter doctor -v`. Android et Chrome ne sont pas requis.
3. Préparer le projet :

   ```sh
   git clone --branch main/ttalk https://github.com/btalal/TTalk.git
   cd TTalk
   flutter pub get --enforce-lockfile
   flutter precache --ios
   (cd ios && pod install)
   open ios/Runner.xcworkspace
   ```

4. Dans **Xcode > Settings > Accounts**, ajouter votre compte Apple. Sélectionner
   le projet bleu **Runner**, puis **TARGETS > Runner > Signing & Capabilities**.
   Cocher **Automatically manage signing**, choisir la **Personal Team** et
   conserver `com.talal.ttalk` s’il est disponible pour votre compte.
5. Brancher et déverrouiller l’iPhone, accepter la confiance du Mac et activer le
   **Mode développeur** dans Réglages > Confidentialité et sécurité si demandé.
6. Dans **Product > Scheme > Edit Scheme… > Run > Info**, choisir **Release**.
   Le mode Debug peut fonctionner depuis Xcode et échouer depuis l’icône sur
   l’iPhone : **Release est nécessaire pour le parcours de lancement autonome**.
7. Choisir l’iPhone comme destination, puis **Product > Run**. Xcode signe et
   installe l’application. Arrêter la session Xcode, débrancher et vérifier
   l’ouverture depuis l’icône TTalk.
8. Dans **Configurer le serveur**, saisir `https://ttalk.fly.dev`. Appairer ce
   téléphone séparément et comparer les numéros de sécurité des contacts.

Avec un compte Apple gratuit, renouveler la signature après **7 jours** en
relançant **Run en Release**, avec le même compte et le même identifiant.
**Ne pas désinstaller TTalk** : la désinstallation efface les données locales.

La CI fournit aussi `ttalk-ios-unsigned.ipa`, un résultat de compilation qui
**ne s’installe pas directement** sans signature. Le parcours validé est celui
des sources dans Xcode ci-dessus. Les installations par des outils tiers ne sont
pas couvertes par ces essais. Aucune publication App Store ou TestFlight n’est
fournie ; elle nécessite une distribution Apple appropriée.

## Mac — version finale

Le projet natif `macos/` est inclus avec l’icône TTalk, le réseau et le Trousseau.
Sur Mac mini M4, la compilation et signature personnelle Xcode en Release sont
validées, ainsi que le lancement depuis Applications et la conservation des
messages après réouverture. Suivre le [guide Mac](MACOS_INSTALL.md).
`ttalk-macos-unsigned.zip` reste non signé et non notarisé : compiler et signer
localement, sans désactiver les protections de macOS.

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
restent ceux de la version Windows, décrits dans `docs/WINDOWS_READINESS.md`.
