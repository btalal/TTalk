# 🔒 TTalk 0.5.1 — Android

🟢 **Version stable** · Messagerie chiffrée de bout en bout pour Android 7.0+.

Cette version améliore les conversations, les contacts et les groupes. Elle
échange messages et fichiers avec TTalk Windows 0.5.1 via le même relais HTTPS.

## Téléchargements

- 📦 **[Télécharger l’APK Android signé](https://github.com/btalal/TTalk/releases/download/android-v0.5.1/ttalk-android.apk)** — `ttalk-android.apk`
- 🔐 [Empreinte SHA256 de l’APK signé](https://github.com/btalal/TTalk/releases/download/android-v0.5.1/ttalk-android.apk.sha256)
- 🖥️ [Version Windows stable 0.5.1](https://github.com/btalal/TTalk/releases/tag/v0.5.1-windows)

Le fichier `ttalk-android-unsigned.apk` présent parmi les Assets est une
archive de compilation **non installable directement**. Utilisez l’APK signé.

## Pour qui ?

Pour les nouveaux utilisateurs Android et les utilisateurs de TTalk Android
0.5.0 souhaitant conserver leur coffre local lors de la mise à jour.

## Nouveautés

- Suppression locale des messages, conversations et contacts, avec confirmation.
- Onglet **Contacts** conservant les contacts après suppression d’une conversation.
- Gestion de l’historique des groupes et possibilité de les quitter localement.
- Noms de contacts et de groupes personnalisables avec vingt icônes intégrées.

Ces noms et icônes restent propres à l’appareil. Les suppressions locales ne
retirent pas les copies des autres participants ni les fichiers déjà enregistrés.
Un message déjà transmis au relais peut encore être livré.

## Corrections

- Code d’appairage renouvelé visible et saisie mieux vérifiée.
- Protection contre les doubles envois, la perte d’un brouillon et la
  réapparition d’un message supprimé lors d’une retransmission.
- Erreurs de sauvegarde signalées et nom de profil actualisé hors ligne.

## Compatibilité

| Plateforme | État |
|---|---|
| Android 7.0+ | ✅ APK signé stable ; ARM64, ARMv7 et x86_64 |
| Windows 10/11 x64 | ✅ [ZIP stable séparé](https://github.com/btalal/TTalk/releases/tag/v0.5.1-windows) |
| iPhone | 🟡 [Préversion non signée](https://github.com/btalal/TTalk/releases/tag/v0.5.1-iphone-mac-preview.1) |

Les notifications push et la réception permanente lorsque l’application
est fermée ne sont pas intégrées ; les messages en attente arrivent à sa
réouverture.

## Mise à niveau

Installez `ttalk-android.apk` **sans désinstaller TTalk**. La clé de signature
est identique à celle de la 0.5.0 : le PIN, les clés, contacts et conversations
restent sur l’appareil. Utilisez le même relais HTTPS que vos contacts.
La désinstallation d’Android efface les données locales de l’application.

## Sécurité

X25519 et HKDF-SHA256 établissent les clés des conversations directes ;
AES-256-GCM chiffre les messages et fichiers. Le coffre local utilise une
clé dérivée du PIN par PBKDF2-HMAC-SHA256, et l’identité de l’appareil est
conservée dans le stockage sécurisé Android. Comparez les numéros de sécurité
des contacts par un autre canal. Le relais voit des métadonnées de routage ;
TTalk n’a pas fait l’objet d’un audit cryptographique indépendant.

## Vérification SHA256

Comparer l’empreinte de l’APK téléchargé avec
[`ttalk-android.apk.sha256`](https://github.com/btalal/TTalk/releases/download/android-v0.5.1/ttalk-android.apk.sha256).
La somme de contrôle ne remplace pas la vérification de la signature Android.

## Documentation

[Installation mobile](https://github.com/btalal/TTalk/blob/main/ttalk/docs/MOBILE_INSTALL.md) ·
[Gestion des conversations](https://github.com/btalal/TTalk/blob/main/ttalk/docs/CHAT_MANAGEMENT.md) ·
[Sécurité et limites](https://github.com/btalal/TTalk/blob/main/ttalk/docs/SECURITY.md) ·
[Relais](https://github.com/btalal/TTalk/blob/main/ttalk/server/README.md)
