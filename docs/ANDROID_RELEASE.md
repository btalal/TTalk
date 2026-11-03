<p align="center"><img src="https://raw.githubusercontent.com/btalal/TTalk/android-v0.5.0/assets/branding/ttalk.png" width="88" height="88" alt="TTalk" /></p>

## 📱 TTalk pour Android — version stable 0.5.0

Messagerie texte chiffrée de bout en bout pour **Android 7.0 et versions ultérieures**.

### ⬇️ Télécharger pour Android

**[Télécharger TTalk Android (.apk signé)](https://github.com/btalal/TTalk/releases/download/android-v0.5.0/ttalk-android.apk)**

Vous cherchez la version ordinateur ? **[Accéder à la version Windows x64](https://github.com/btalal/TTalk/releases/tag/v0.5.0-windows)**.

### Installation ou mise à jour

1. Sur votre téléphone, téléchargez **`ttalk-android.apk`** avec le lien ci-dessus.
2. Ouvrez le fichier et autorisez cette source d’installation si Android le demande.
3. Pour mettre à jour la préversion, installez l’APK **sans désinstaller TTalk** afin de conserver vos données. La clé de signature est identique.
4. Ouvrez TTalk et utilisez le même relais HTTPS que vos contacts Windows ou Android.

### Fonctionnalités validées

- Messages et fichiers entre Android et Windows.
- Contacts et historique conservés après redémarrage.
- Réception des messages en attente à la réouverture.
- Groupes et transfert de propriété.

Ces échanges ont été testés sur un smartphone Android et deux PC Windows x64.

### À savoir

**Les notifications lorsque l’application est fermée ne sont pas intégrées.** La réception reprend à l’ouverture de TTalk. Cette fonctionnalité est reportée ; aucune dépendance Firebase/APNs n’a été ajoutée.

Un relais hébergé reste nécessaire. Cette release concerne Android ; la version iPhone reste en préversion.

<details>
<summary>Autres fichiers et documentation</summary>

- `ttalk-android.apk.sha256` : empreinte permettant de vérifier l’intégrité de l’APK signé.
- `ttalk-android-unsigned.apk` et son empreinte : fichiers de compilation destinés à la signature, à ne pas utiliser pour installer TTalk.
- Les liens **Source code** générés par GitHub contiennent les sources, pas l’application à installer.
- Architectures incluses : ARM64, ARMv7 et x86_64.
- [Guide d’installation mobile](https://github.com/btalal/TTalk/blob/main/ttalk/docs/MOBILE_INSTALL.md)

</details>
