# Feuille de route TTalk

Cette liste indique les prochains axes de travail. Elle ne promet ni date de
livraison ni compatibilité avant validation sur appareils réels.

## Disponible en 0.5.1

- Versions Windows x64 et Android signées.
- Versions finales iPhone et macOS pour signature personnelle Xcode ; essais
  validés sur iPhone 17 Pro (iOS 27.2) et Mac mini M4 le 6 novembre 2026.
- Messages directs, pièces jointes jusqu’à 5 Mo, groupes et gestion des membres.
- Relais auto-hébergeable et file d’attente des messages chiffrés.
- Appairage et vérification des numéros de sécurité.

## Lot 0.6 — essais fonctionnels confirmés le 6 novembre 2026

Le propriétaire confirme les applications iPhone, macOS, Android et Windows
fonctionnelles, ainsi que le verrouillage manuel et à 5 minutes, la sauvegarde/
restauration, le retrait d’un membre et la biométrie sur l’appareil testé.
Les compilations natives et 81 tests Flutter ont réussi. Ces essais ne constituent
pas un audit. Voir [le suivi détaillé](NEXT_VERSION.md) et [les limites](NEXT_SECURITY.md).
Les packages installés en parallèle sont des variantes de test ; leur validation
ne transforme pas automatiquement les anciens artefacts en distributions finales.

## Linux 0.6.1 — publié le 8 novembre 2026

RPM Fedora 45 et DEB Ubuntu 24.04/26.04/Zorin OS Pro 18.1, en Intel/AMD 64 bits.
Fonctionnement rapporté sur Fedora et Zorin ; révision 2 pour les emojis couleur.
Voir [les essais et limites](LINUX_VALIDATION.md).

## Prochaines étapes

- Étendre les essais Apple aux groupes, pièces jointes, interruptions réseau
  et mises à jour ; préparer une distribution Apple signée et notarisée.
- Conserver le [compte rendu des essais Apple](APPLE_VALIDATION.md).
- Compléter les captures Windows par des vues Android et de groupe authentiques.
- Étudier les notifications mobiles et la réception en arrière-plan.
- Renforcer le modèle cryptographique des conversations directes et des groupes,
  puis rechercher un audit indépendant avant toute promesse de sécurité accrue.
- Clarifier les sauvegardes, la restauration et la migration entre appareils.

## Révision de sécurité suivante — décision du 6 novembre 2026

Le chantier Double Ratchet et la refonte des rotations de groupe sont reportés
à la révision suivant le lot 0.6, à la demande du propriétaire. Ils ne sont
pas annoncés comme implémentés. Le [plan conservé dans le dépôt](SECURITY_NEXT_REVISION.md)
précise les exigences de migration, de tests et de revue. Les notifications push
restent reportées.

## Pistes à évaluer

- Appels audio et vidéo.
- Synchronisation de l’historique entre plusieurs appareils.

Ces pistes n’ont pas encore de calendrier ni d’engagement de réalisation.

Les limites actuelles sont détaillées dans le [modèle de sécurité](SECURITY.md).
