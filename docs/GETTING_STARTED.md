# Démarrer avec TTalk

## Installer

Télécharger la version adaptée à votre appareil depuis les
[releases officielles](https://github.com/btalal/TTalk/releases). Sous Windows,
extraire toute l’archive `ttalk-windows-x64.zip`, puis lancer `TTalk.exe` ; le
dossier `app` doit rester à côté de ce lanceur. Sous Android, installer l’APK
**signé** `ttalk-android.apk`. Pour iPhone et macOS, consulter le
[guide mobile](MOBILE_INSTALL.md) et le [guide Mac](MACOS_INSTALL.md) : leurs
archives ne sont pas prêtes à installer directement.

## Configurer un relais

1. Disposer d’un relais TTalk accessible en HTTPS. Vous pouvez héberger le vôtre
   en suivant le [guide du relais](../server/README.md).
2. Dans **Configurer le serveur**, saisir son adresse HTTPS sur chaque appareil.
3. Créer ou saisir son PIN, puis choisir **Mon nom**.

Une adresse distante doit utiliser HTTPS/WSS avec un certificat valide. Pour
tester un relais sur le même PC, l’adresse `http://localhost:8080` est acceptée.
Les appareils qui échangent doivent utiliser le même relais. Les identités et
les conversations sont propres à chaque appareil.

## Appairer un contact

1. Un appareil génère un **code d’appairage à six caractères**.
2. L’autre saisit ce code dans **Appairer un contact**.
3. Le relais échange les clés publiques des deux appareils.
4. Comparez les **numéros de sécurité** par un autre canal fiable avant de
   considérer le contact comme vérifié. Le code seul n’empêche pas une
   substitution de clé par un relais malveillant.

Les messages composés sans réseau restent dans la file locale chiffrée et sont
renvoyés lors de la reconnexion. Le relais conserve les paquets destinés aux
appareils absents pendant **sept jours au maximum par défaut**. Une horloge
indique un envoi en attente d’acceptation ; une coche indique l’acceptation par
le relais, deux coches la réception et les coches bleues l’ouverture de la
conversation. Ces états ne prouvent pas qu’une personne a lu le texte.

## Groupes, fichiers et suppression

Dans l’onglet **Groupes**, créer un groupe avec des contacts déjà appairés.
Le propriétaire peut gérer les membres et transférer la propriété. Une
invitation doit être acceptée. Les détails et les limites des suppressions
locales figurent dans le [guide des conversations](CHAT_MANAGEMENT.md).

Le bouton 📎 permet de joindre un fichier de **5 Mo maximum**. Le transfert
est chiffré de bout en bout. Après réception, le fichier est enregistré
**déchiffré** sur l’appareil destinataire ; protéger aussi cet appareil et ses
sauvegardes. Voir le [modèle de sécurité](SECURITY.md).
