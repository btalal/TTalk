# Contribuer à TTalk

Utiliser Flutter **3.47.9**, Dart fourni avec ce SDK et Node **24** pour les tests
du relais. Les développements sont proposés par pull request vers `main/ttalk`.

```sh
npm ci --prefix server
npm test --prefix server
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
```

Xcode et CocoaPods sont nécessaires pour iPhone/Mac ; Visual Studio avec les outils
C++ pour Windows ; JDK 21 et les outils Android épinglés dans les workflows pour Android.

Préserver le fichier de verrouillage des dépendances et les tests de migrations.
Inclure les scénarios de panne de stockage et la compatibilité avec les versions
publiées pour les changements de protocole. Une primitive cryptographique ou un
protocole maison supplémentaire nécessite une revue dédiée avant publication.

Pour l’interface, tester un téléphone de 320 pixels, un clavier ouvert, une grande
taille de texte, clair/sombre et une fenêtre de bureau à deux colonnes. Utiliser
des données fictives dans les captures ; indiquer la plateforme et la provenance.

Une contribution décrit le problème, le comportement obtenu, les tests effectués
et les limites restantes. Ne jamais versionner les clés de signature, certificats
privés, profils de compte Apple, secrets serveur ou données utilisateur.
