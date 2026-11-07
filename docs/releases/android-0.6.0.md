# 🔒 TTalk 0.6.0 — Android

🟡 **Signature finale en attente — APK non installable directement**

## Téléchargements

- [APK à signer](https://github.com/btalal/TTalk/releases/download/v0.6.0-android/ttalk-android-unsigned.apk)
- [Consignes de signature](https://github.com/btalal/TTalk/releases/download/v0.6.0-android/INSTALLATION-SIGNATURE.txt)

Publication en attente de la clé de signature d’origine. Cet APK non signé ne s’installe pas directement. La version finale Android 0.5.1 reste la référence installable.

## Pour qui ?

Pour le propriétaire qui signe le package avec le keystore Android existant. L’APK final signé doit garder le certificat de 0.5.1 pour permettre une mise à jour sans désinstallation.

## Nouveautés

- Interface bureau à deux colonnes et navigation mobile Discussions, Contacts, Réglages.
- Recherche locale, filtres, conversations épinglées et archivées.
- Invitations QR et liens à coller ; réponses citées et réactions chiffrées entre clients compatibles.
- Verrouillage manuel et automatique ; biométrie facultative si prise en charge par le système.
- Sauvegarde locale chiffrée à phrase de passe indépendante ; restauration dans un coffre vide.

## Corrections

- Nouvelle clé de groupe transmise individuellement aux membres restants après exclusion.
  Refus d'une rotation sous l'ancienne clé collective ou avec des membres incompatibles.
- Rejet des accords X25519 invalides et vérification de l'identité attendue dans une invitation.
- Corrections de persistance, d'affichage sur petit écran et du SDK du plugin biométrique Android.

## Compatibilité

Windows 10/11 x64, Android 7.0+, iPhone iOS 15+ et macOS 12+.
Les variantes ont été déclarées fonctionnelles par le propriétaire sur les quatre plateformes.
Les essais Apple utilisent iPhone 17 Pro (iOS 27.2) et Mac mini M4. Les autres modèles
ne sont pas déclarés testés. Windows Hello n'est pas intégré ; le Mac mini nécessite
un clavier Touch ID compatible pour proposer la biométrie.
Les réactions et rotations de groupe exigent des contacts compatibles 0.6.
Aucun changement du relais protocole 2 n'est requis.

## Mise à niveau et installation

Conserver l'application existante et son identifiant pour préserver ses données.
Ne pas désinstaller pour mettre à jour ou renouveler une signature Apple.
Les variantes TTalk Test ont des identifiants et coffres distincts ; aucune fusion
avec la version finale n'est fournie. Appairer séparément chaque appareil.
Les sauvegardes excluent les pièces jointes et les envois en attente. Arrêter
l'identité d'origine avant de la restaurer sur un autre appareil.

## Sécurité

X25519, HKDF-SHA256 et AES-256-GCM ; coffre local protégé par PIN et stockage système.
Comparer les numéros de sécurité des contacts par un autre canal. Le relais voit
des métadonnées de routage. TTalk n'a pas fait l'objet d'un audit indépendant.
Double Ratchet, époques de groupe et revue indépendante sont planifiés pour la
prochaine révision et ne sont pas présentés comme implémentés.
Les notifications push restent reportées ; réception mobile application fermée non garantie.
Les fichiers déjà déchiffrés sur disque ne sont pas effacés par le verrouillage.

## Vérification SHA256

Comparer chaque fichier téléchargé aux sommes publiées. Les empreintes vérifient
l'intégrité ; elles ne remplacent ni une signature de distribution ni un audit.

## Documentation

[Fonctions et essais](https://github.com/btalal/TTalk/blob/main/ttalk/docs/NEXT_VERSION.md) ·
[Sécurité et limites](https://github.com/btalal/TTalk/blob/main/ttalk/docs/NEXT_SECURITY.md) ·
[Prochaine révision](https://github.com/btalal/TTalk/blob/main/ttalk/docs/SECURITY_NEXT_REVISION.md)

Signaler les problèmes dans les issues sans publier de PIN, clé ou contenu privé.
