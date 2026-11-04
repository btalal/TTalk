# TTalk 0.5.1 — Android final et iPhone en préversion

Android et iOS utilisent le même relais **0.4 / protocole 2** que Windows
0.4 / 0.5.1. Chaque téléphone possède sa propre identité : appairer chaque appareil
séparément, saisir le même serveur HTTPS, puis comparer les numéros de sécurité.
Le relais actuel est `https://ttalk.fly.dev` ; saisir cette adresse dans
**Configurer le serveur** sur chaque nouvel appareil. Elle n’est pas préconfigurée.

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

## iPhone — préversion et signature personnelle

iOS **15 minimum**. Le projet utilise Flutter **3.47.9**, CocoaPods et Xcode.
Sur un Mac mini M4, la méthode recommandée avec un compte Apple gratuit est de
laisser Xcode **signer et installer directement** l’application sur son iPhone :

1. Installer Xcode, Flutter 3.47.9 et CocoaPods, puis vérifier `flutter doctor -v`.
2. Récupérer la branche `main/ttalk` et préparer le projet :

   ```sh
   git clone --branch main/ttalk https://github.com/btalal/TTalk.git
   cd TTalk
   flutter pub get --enforce-lockfile
   (cd ios && pod install)
   open ios/Runner.xcworkspace
   ```

3. Dans Xcode, ajouter son compte dans **Xcode > Settings > Accounts**. Sélectionner
   la cible **Runner**, puis **Signing & Capabilities** : cocher **Automatically
   manage signing** et choisir sa **Personal Team**. Conserver l’identifiant
   d’application `com.talal.ttalk` s’il est disponible pour ce compte.
4. Relier l’iPhone par USB, lui faire accepter la confiance du Mac, puis activer
   le **Mode développeur** dans Réglages > Confidentialité et sécurité si demandé.
5. Choisir l’iPhone comme destination dans Xcode et lancer **Product > Run**.
   Xcode crée le profil de développement, signe et installe l’application.
   Une fois TTalk ouvert, saisir `https://ttalk.fly.dev` dans **Configurer le serveur**.

Un compte gratuit permet les essais personnels mais les profils expirent après
**7 jours** : reconstruire et réinstaller depuis Xcode avec le même compte et le
même identifiant d’application. Ne pas désinstaller TTalk pour renouveler la
signature : la désinstallation efface les données locales.

La CI GitHub produit aussi `ttalk-ios-unsigned.ipa`. Ce fichier **ne s’installe
pas directement**. Pour signer cette IPA sur Windows, [Sideloadly](https://sideloadly.io/)
accepte un compte Apple gratuit et réinstalle l’app sur l’iPhone ; la même limite
de 7 jours s’applique. Saisir ses identifiants uniquement dans l’outil choisi,
jamais dans le dépôt ou auprès d’un tiers. Cette voie doit encore être validée
sur un véritable iPhone avec la version actuelle de TTalk.

La Personal Team ne permet pas de distribuer TTalk par TestFlight ou l’App Store.
Une telle distribution nécessite l’abonnement Apple Developer, une signature de
distribution et la validation d’Apple.

## Mac — préversion native

La release mobile inclut `ttalk-macos-preview.zip`, une application Flutter
macOS distincte de l’IPA iPhone. Elle n’est pas signée avec Developer ID ni
notarisée ; macOS peut refuser son ouverture après téléchargement. Le
[guide macOS](MACOS_INSTALL.md) décrit la compilation locale et les essais.

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
