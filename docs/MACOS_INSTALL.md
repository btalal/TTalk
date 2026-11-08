# TTalk 0.5.1 pour Mac — version finale

Parcours validé sur **Mac mini M4 sous macOS 27.2**, le 6 novembre 2026 :
compilation Release avec Flutter 3.47.9, CocoaPods 1.17.0 et Xcode 27.2,
signature personnelle, lancement depuis Applications, serveur, contacts,
envoi/réception de messages et conservation des messages après réouverture.
Voir le [compte rendu précis](APPLE_VALIDATION.md).

Le projet cible macOS **12 minimum**. Les autres Mac et versions de macOS
ne sont pas couverts par ces essais. Le projet natif `macos/` et l’icône TTalk
commune à la version iPhone sont maintenant inclus dans le dépôt.

## Préparer le Mac

1. Installer Xcode depuis l’App Store. L’ouvrir, accepter sa licence et installer
   les composants proposés. Dans Terminal :

   ```sh
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```

2. Installer Flutter **3.47.9 pour Apple Silicon (ARM64)** depuis les
   [sources officielles Flutter](https://docs.flutter.dev/install/archive).
   Ajouter son dossier `bin` au PATH, ainsi que Homebrew si utilisé pour CocoaPods.
   Installer CocoaPods avec `brew install cocoapods`, puis vérifier :

   ```sh
   flutter --version
   pod --version
   flutter doctor -v
   ```

   Les alertes Android et Chrome ne bloquent pas la compilation Mac.

## Compiler et signer avec Xcode

```sh
git clone --branch main/ttalk https://github.com/btalal/TTalk.git
cd TTalk
flutter pub get --enforce-lockfile
flutter precache --macos
flutter build macos --release --config-only
(cd macos && pod install)
open macos/Runner.xcworkspace
```

1. Dans **Xcode > Settings > Accounts**, ajouter votre compte Apple.
2. Sélectionner le projet bleu **Runner**, puis **TARGETS > Runner**.
3. Dans **Signing & Capabilities**, cocher **Automatically manage signing**,
   choisir votre **Personal Team** et conserver `com.talal.ttalk` si disponible.
   Les droits du Trousseau nécessitent une signature de développement.
4. Dans **Product > Scheme > Edit Scheme… > Run > Info**, vérifier
   **Build Configuration : Release**.
5. Choisir **My Mac**, puis **Product > Run**. Si le Trousseau demande d’autoriser
   la signature, saisir le mot de passe de la session Mac.

Le dossier natif fourni contient les droits du Trousseau et du réseau sortant.
Ne pas régénérer `macos/` : cela risquerait de perdre ces réglages et l’icône.

## Mettre TTalk dans Applications

Arrêter l’exécution dans Xcode. Dans le navigateur du projet, sous **Products**,
faire un clic droit sur **ttalk.app > Show in Finder**, puis copier l’application
compilée dans **Applications**. Remplacer l’ancienne copie si nécessaire, sans
effacer les données de l’application ni son Trousseau.

Ouvrir TTalk depuis Applications et saisir l'url de votre relais privé dans
**Configurer le serveur**, ou l’adresse de votre propre relais HTTPS.
Chaque appareil a sa propre identité : appairer le Mac séparément et comparer
les numéros de sécurité des contacts.

## Si `PhaseScriptExecution` échoue sur M4

Lire la première erreur dans le journal de compilation. Si elle indique
`incorrect architecture` pour `impellerc` ou `font-subset`, fermer la compilation
et régénérer le cache depuis le **Terminal natif du Mac**, hors Rosetta :

```sh
uname -m
flutter precache --macos --ios --force
```

`uname -m` doit indiquer `arm64`. Relancer ensuite la compilation. Le nom historique
`darwin-x64` du dossier Flutter peut être conservé même pour ses outils ARM64 ;
c’est l’architecture de l’exécutable qui compte. Ne pas modifier le code généré.

## Archives GitHub

`ttalk-macos-unsigned.zip` est un résultat de compilation CI **non signé**,
sans certificat Developer ID ni notarisation Apple. Ce n’est pas une application
prête à ouvrir après téléchargement ; macOS peut la bloquer. Le parcours validé
est la compilation et signature personnelle ci-dessus. Ne pas désactiver les
protections de macOS pour lancer une archive bloquée.

Les anciennes archives `ttalk-macos-preview.zip` restent historiques et peuvent
encore contenir l’icône Flutter par défaut. Utiliser la release finale et ses sources.
