# TTalk pour macOS — préversion

Cette préversion utilise le même code Flutter que TTalk pour Windows, Android et
iPhone. Elle crée une identité propre au Mac ; appairer ce nouvel appareil avec
chaque contact et vérifier les numéros de sécurité. Dans **Configurer le serveur**,
saisir l'url de votre relais privé.

L'archive `ttalk-macos-preview.zip` contient l'application macOS. Elle a été
compilée sur macOS 15 par GitHub Actions, mais n'est pas signée avec un certificat
**Developer ID** et n'est pas **notarisée** par Apple. macOS peut donc refuser son
ouverture après téléchargement. Ne désactivez pas les protections de macOS pour
tester cette préversion. La voie de développement sur votre propre Mac est :

```sh
git clone --branch main/ttalk https://github.com/btalal/TTalk.git
cd TTalk
flutter create --platforms=macos --org com.talal .
flutter pub get --enforce-lockfile
flutter run -d macos
```

Flutter 3.47.9, Xcode et CocoaPods sont nécessaires pour compiler cette version.
La CI génère actuellement le dossier natif `macos/` au moment du build ; il ne
figure pas encore dans le dépôt. Le build automatisé vérifie la compilation,
mais l'interface, le Trousseau, la connexion et les échanges restent à tester
sur un Mac réel avant de considérer cette version comme stable.

Pour distribuer une application Mac qui s'ouvre normalement après téléchargement,
il faudra une signature Developer ID et une notarisation Apple. Ces étapes
nécessitent un abonnement Apple Developer et ne sont pas incluses dans cette
préversion.
