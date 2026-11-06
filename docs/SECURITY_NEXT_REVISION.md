# Sécurité — prochaine révision après le lot 0.6

Décision du propriétaire du 6 novembre 2026 : conserver ce chantier pour la
prochaine révision plutôt que modifier précipitamment le protocole avant la
publication. Ce document est la mémoire durable de cette décision.

## Déjà réalisé dans le lot 0.6 en cours de publication

Verrouillage manuel/automatique du coffre, biométrie facultative protégée par
le système, sauvegarde chiffrée à phrase indépendante, rejet des accords X25519
invalides, et remise individuelle de la nouvelle clé aux membres restants après
exclusion. Ces changements ne sont pas ceux des archives finales 0.5.1.
Le propriétaire rapporte les quatre applications fonctionnelles et valide le
verrouillage à 5 minutes et manuel, sauvegarde/restauration, retrait d'un membre
et biométrie sur l'appareil testé. Ce sont des essais fonctionnels, pas un audit.

## Conversations directes

- Choisir une implémentation de protocole revue et maintenue ; vérifier sa licence
  et la disponibilité sur Flutter/iOS/Android/macOS/Windows avant intégration.
- Préparer Double Ratchet : confidentialité des anciens messages après compromission
  d'une clé courante et récupération après compromission selon les hypothèses du protocole.
- Définir l'authentification initiale, la négociation de version et la protection
  contre les replis silencieux sur le protocole précédent.
- Tester les messages hors ordre, doublons, clés sautées avec limites mémoire,
  pertes réseau, écritures interrompues et redémarrages.
- Définir la migration des sessions, les sauvegardes et les restaurations, sans
  réutiliser des états de ratchet ou promettre de synchronisation multiappareil.

## Groupes

- Définir les époques de clés et une récupération bornée pour les messages retardés.
- Authentifier les auteurs et les contrôles de groupe face à un membre malveillant
  et à un relais compromis ; définir les pouvoirs du propriétaire.
- Traiter les départs volontaires, exclusions, rotations simultanées et appareils
  hors ligne ; ne jamais remettre une nouvelle clé à un membre exclu.
- Évaluer un protocole de groupe éprouvé, dont MLS, avant toute refonte artisanale.

## Critères de validation

Spécification et modèle de menace écrits, revue du protocole et de l'implémentation,
tests adversariaux et de migration sur les quatre plateformes, puis revue
indépendante. Ne pas annoncer Double Ratchet, MLS, confidentialité persistante
ou audit avant réalisation et validation effective.

## Hors de ce chantier

Notifications push toujours reportées à la demande du propriétaire. Aucun
abonnement Apple, projet Firebase ni secret n'est requis pour conserver ce plan.
