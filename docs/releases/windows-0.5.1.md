# 🔒 TTalk 0.5.1 — Windows x64

🟢 **Version stable** · Messagerie chiffrée de bout en bout, relais au choix.

Cette version facilite la gestion des conversations, contacts et groupes sur
Windows 10/11. Les messages et fichiers sont compatibles avec TTalk Android 0.5.1.

## Téléchargements

- 📦 **[Télécharger TTalk pour Windows](https://github.com/btalal/TTalk/releases/download/v0.5.1-windows/ttalk-windows-x64.zip)** — `ttalk-windows-x64.zip`
- 🔐 [Empreinte SHA256 du ZIP](https://github.com/btalal/TTalk/releases/download/v0.5.1-windows/ttalk-windows-x64.zip.sha256)
- 📱 [Version Android stable 0.5.1](https://github.com/btalal/TTalk/releases/tag/android-v0.5.1)

## Pour qui ?

Pour les nouveaux utilisateurs Windows x64 et les utilisateurs de TTalk 0.5.0.
Les anciens groupes de 0.3.6 exigent une recréation : voir « Mise à niveau ».

## Nouveautés

- Suppression locale des messages, conversations et contacts, avec confirmation.
- Onglet **Contacts** conservant les contacts après suppression d’une conversation.
- Gestion de l’historique des groupes et possibilité de les quitter localement.
- Noms de contacts et de groupes personnalisables avec vingt icônes intégrées.

## Corrections

- Code d’appairage renouvelé rendu visible et saisie des codes mieux vérifiée.
- Protection contre les doubles envois, la perte d’un brouillon et la
  réapparition d’un message supprimé lors d’une retransmission.
- Erreurs de sauvegarde signalées et nom de profil actualisé hors ligne.

## Aperçu

**Conversation et menu de gestion**

![Conversation TTalk sur Windows avec des messages de test](https://raw.githubusercontent.com/btalal/TTalk/68ef4b23e210025f9e358c0a5736993c4dcf3668/docs/media/windows-chat.png)

**Appairage d’un contact**

![Fenêtre d’appairage sur Windows](https://raw.githubusercontent.com/btalal/TTalk/68ef4b23e210025f9e358c0a5736993c4dcf3668/docs/media/windows-pairing.png)

## Compatibilité

| Plateforme | État |
|---|---|
| Windows 10/11 x64 | ✅ Cette archive stable |
| Android 7.0+ | ✅ [APK stable séparé](https://github.com/btalal/TTalk/releases/tag/android-v0.5.1) |
| iPhone et macOS | 🟢 [Versions finales Apple 0.5.1](https://github.com/btalal/TTalk/releases/tag/v0.5.1-apple) — compilation et signature personnelle dans Xcode |

Un relais TTalk HTTPS commun est nécessaire pour échanger entre appareils.
Les notifications mobiles quand l’application est fermée ne sont pas intégrées.

## Mise à niveau

1. Télécharger puis **extraire entièrement** le ZIP.
2. Lancer `TTalk.exe` à la racine et conserver `app/` à côté.
3. Configurer le même relais HTTPS que vos contacts.

Depuis 0.5.0, le PIN, les clés, contacts et conversations sont conservés.
Depuis 0.3.6, les anciens groupes restent consultables dans l’historique mais
**doivent être recréés** avec le nouveau relais. Les suppressions de la 0.5.1
ne retirent que les copies locales et les fichiers déjà enregistrés restent
sur disque.

## Sécurité

X25519 et HKDF-SHA256 établissent les clés des conversations directes ;
AES-256-GCM chiffre les messages et fichiers. Le coffre local utilise une
clé dérivée du PIN par PBKDF2-HMAC-SHA256. Comparez les numéros de sécurité
des contacts par un autre canal pour détecter une substitution de clé.
Le relais voit des métadonnées de routage et TTalk n’a pas fait l’objet d’un
audit cryptographique indépendant.

## Vérification SHA256

Le fichier `.sha256` accompagne le ZIP. Sous PowerShell :

```powershell
Get-FileHash .\ttalk-windows-x64.zip -Algorithm SHA256
```

Comparer le résultat à l’empreinte publiée avec la release. Les liens
« Source code » générés par GitHub ne sont pas l’application à lancer.

## Documentation

[Démarrage](https://github.com/btalal/TTalk/blob/main/ttalk/docs/GETTING_STARTED.md) ·
[Gestion des conversations](https://github.com/btalal/TTalk/blob/main/ttalk/docs/CHAT_MANAGEMENT.md) ·
[Sécurité et limites](https://github.com/btalal/TTalk/blob/main/ttalk/docs/SECURITY.md) ·
[Relais](https://github.com/btalal/TTalk/blob/main/ttalk/server/README.md)
