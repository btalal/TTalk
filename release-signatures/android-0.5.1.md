<p align="center"><img src="https://raw.githubusercontent.com/btalal/TTalk/android-v0.5.1/assets/branding/ttalk.png" width="88" height="88" alt="TTalk" /></p>

## 📱 TTalk pour Android — version stable 0.5.1

Messagerie texte chiffrée de bout en bout pour **Android 7.0 et versions ultérieures**.

### ⬇️ Télécharger pour Android

**[Télécharger TTalk Android (.apk signé)](https://github.com/btalal/TTalk/releases/download/android-v0.5.1/ttalk-android.apk)**

Vous cherchez la version ordinateur ? **[Accéder à la version Windows x64](https://github.com/btalal/TTalk/releases/tag/v0.5.1-windows)**.

### Installation ou mise à jour

1. Sur votre téléphone, téléchargez **`ttalk-android.apk`** avec le lien ci-dessus.
2. Ouvrez le fichier et autorisez cette source d’installation si Android le demande.
3. Pour mettre à jour la version 0.5.0 ou la préversion, installez l’APK **sans désinstaller TTalk** afin de conserver vos données. La clé de signature est identique.
4. Ouvrez TTalk et utilisez le même relais HTTPS que vos contacts Windows ou Android.

### Nouveautés de la version 0.5.1

- **Menus ⋮** pour supprimer messages, conversations et contacts, avec confirmation.
- **Groupes** : effacer l’historique ou quitter et supprimer le groupe de cet appareil.
- **Onglet Contacts** pour retrouver un contact après suppression de la conversation.
- **Personnalisation locale** des noms de contacts/groupes et choix parmi vingt icônes.
- **Correctifs** : code d’appairage renouvelé visible, saisie des codes vérifiée,
  protection contre les doubles envois et la perte d’un brouillon, erreurs de
  sauvegarde signalées et nom actualisé hors ligne.
- **Fiabilité** : choix conservés dans le coffre chiffré ; protection contre la
  réapparition d’un message supprimé lors d’une retransmission.

Les noms et icônes restent propres à cet appareil. Les suppressions locales ne
retirent pas les copies des autres participants ni les fichiers déjà enregistrés.
Un envoi déjà transmis au relais peut encore être livré.

[Guide des nouveaux menus](https://github.com/btalal/TTalk/blob/main/ttalk/docs/CHAT_MANAGEMENT.md)

### Fonctions conservées

- Messages et fichiers entre Android et Windows.
- Contacts et historique conservés après redémarrage.
- Réception des messages en attente à la réouverture.
- Groupes et transfert de propriété.

Le périmètre précédent a été validé sur un smartphone Android et deux PC Windows x64.
Les nouveaux menus disposent de tests automatisés et d’un contrôle natif sur émulateur ; les essais sur appareils réels restent à poursuivre.

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
