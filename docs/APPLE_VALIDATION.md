# TTalk 0.5.1 — validation des versions finales Apple

Essais manuels effectués et confirmés par le propriétaire le **6 novembre 2026**.
Ce compte rendu porte sur des applications compilées en **Release**, signées
personnellement avec Xcode, et un relais HTTPS privé. Pour configurer le serveur, saisir l'url de votre relais privé.

| Appareil | Environnement | Résultats confirmés |
|---|---|---|
| iPhone 17 Pro | iOS **27.2**, compilation depuis un Mac mini M4 avec Xcode 27.2, Flutter 3.47.9 et CocoaPods 1.17.0 | Installation, lancement depuis l’icône sans session Xcode, configuration et test du serveur, ajout d’un contact, envoi et réception de messages |
| Mac mini M4 | macOS 27.2, Xcode 27.2, Flutter 3.47.9 et CocoaPods 1.17.0 | Compilation et signature locale, copie dans Applications, lancement depuis Applications, configuration du serveur, ajout d’un contact, envoi et réception de messages, conservation des messages reçus après fermeture et réouverture |

## Corrections nécessaires pendant l’installation

- Sélectionner Xcode complet avec `xcode-select`, accepter sa licence et terminer
  le premier lancement ; rendre CocoaPods accessible dans le PATH du Terminal.
- Utiliser les outils Flutter **ARM64** sur M4. Les exécutables `impellerc` et
  `font-subset` Intel d’un cache mal détecté provoquaient `PhaseScriptExecution`.
- Installer la version iPhone en **Release** pour le lancement autonome.
- Générer puis conserver le projet natif Mac, remplacer l’icône Flutter par
  l’icône TTalk et configurer le réseau sortant et le Trousseau.
- Choisir sa Personal Team dans Xcode pour signer les droits d’accès au Trousseau.
- Copier l’application Mac compilée dans Applications ; Xcode la lançait
  initialement depuis DerivedData.

## Portée de la validation

Ces résultats motivent la publication **finale 0.5.1 pour installation personnelle**
sur iPhone et Mac. Ils ne constituent pas un audit de sécurité ni une validation
de toutes les fonctions sur toutes les versions d’iOS ou tous les Mac.

Les groupes, transferts de propriété, pièces jointes, pertes réseau, réception
différée, renouvellements de signature et migrations ne sont pas couverts par
ces nouveaux essais Apple. La persistance après réouverture est explicitement
confirmée sur Mac ; aucune nouvelle affirmation de test équivalent sur iPhone
n’est ajoutée ici. Le lancement a été vérifié sans Xcode ; un redémarrage complet
des appareils n’a pas été consigné.

Les notifications push et la réception mobile permanente en arrière-plan ne
sont pas intégrées. Chaque appareil conserve sa propre identité et doit être
appairé séparément ; aucune synchronisation automatique d’historique n’est fournie.

## Signature et distribution

Les archives GitHub Actions sont **non signées** et nécessitent une signature
personnelle. L’installation validée utilise les sources et Xcode en Release.
La version Mac n’a pas de signature Developer ID ni de notarisation Apple.
Il ne s’agit pas d’une publication App Store ou TestFlight.

Avec une Personal Team gratuite, renouveler la signature iPhone après sept jours,
sans désinstaller TTalk, avec le même compte et `com.talal.ttalk`.
Ne pas publier de certificat privé, profil de compte ou clé de signature.

[Installer sur iPhone](MOBILE_INSTALL.md) · [Installer sur Mac](MACOS_INSTALL.md)
