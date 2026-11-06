# Sécurité de la branche 0.6 — portée et travail restant

Cette note documente un renforcement partiel, pas un audit ni une garantie de
sécurité équivalente à Signal, SimpleX ou MLS.

## Changements

1. **Coffre.** Verrouillage automatique et manuel ; opérations séquencées avant
   déchargement, fermeture de la connexion, suppression des références aux
   historiques et clés de session. Une erreur de dernière écriture ne laisse pas
   le coffre déverrouillé. Dart/les systèmes ne garantissent pas la purge physique
   immédiate des anciennes allocations mémoire.
2. **Biométrie.** La clé dérivée du PIN est conservée uniquement sur activation
   explicite dans un élément Keychain/Keystore exigeant la biométrie à la lecture.
   Les modes non protégés du plugin sur Windows/Linux/web ne sont pas utilisés.
   Les tests de la protection système, de l’invalidation d’une empreinte et des
   annulations nécessitent des appareils réels. Le PIN reste une voie de secours.
3. **Sauvegarde.** AES-256-GCM, sel indépendant de 32 octets et PBKDF2-HMAC-SHA256
   à 600 000 itérations avec phrase de passe de 16 caractères minimum ; limites
   avant décodage/KDF. Mauvaise phrase et contenu altéré sont rejetés. Les chemins
   de pièces jointes ne sont jamais réutilisés lors d’un import. Le journal de
   restauration permet de reprendre les écritures interrompues entre magasins.
4. **Retrait d’un membre.** La nouvelle clé est enveloppée séparément dans la
   session chiffrée de chacun des membres restants. Elle n’est jamais diffusée
   sous l’ancienne clé partagée. Sans session/capacité de chaque destinataire,
   l’action est refusée. Les clients anciens doivent être mis à jour avant ce parcours.
5. **Identité.** Le lien QR peut épingler l’identité attendue lors de l’appairage.
   Le marquage « vérifié » reste une action explicite après comparaison des numéros.
6. **Persistance.** Les listes sont instantanées au moment de la mise en file d’une
   sauvegarde du coffre ; les modifications de présentation et de réaction sont
   rétablies si l’enregistrement échoue.

## Limites qui restent ouvertes

- Les conversations directes utilisent toujours les sessions X25519/HKDF de la
  version 0.5.1 ; **aucune confidentialité persistante par Double Ratchet** n’est
  ajoutée. Une intégration exige choix d’une implémentation revue, vérification de
  licence, gestion des messages hors ordre, migrations, récupération et tests adversariaux.
- Le protocole de groupe à clé partagée ne devient pas MLS. Le départ volontaire,
  les contrôles de groupe, les concurrents de rotation et l’authenticité de l’auteur
  vis-à-vis d’un membre malveillant et d’un relais compromis exigent une revue plus large.
- Les messages de groupe chiffrés avant une rotation et reçus après elle peuvent
  ne plus être lisibles. Définir une politique d’époques et de récupération bornée
  avant une diffusion stable. Ne pas réintroduire de remise de nouvelle clé à un exclu.
- Un fichier de sauvegarde contient l’identité privée : deux restaurations actives
  simultanées ne sont pas des appareils liés et ne sont pas prises en charge.
- Les fichiers déjà déchiffrés hors du coffre ne sont pas effacés par le verrouillage.
- Un appareil compromis peut accéder à des données déjà déverrouillées.

## Conditions avant une nouvelle version finale

Revue indépendante du protocole et du stockage biométrique, tests sur les quatre
plateformes et tests de perte réseau/stockage, refus des autorisations et migrations.
Les changements sont maintenus dans une branche de développement pour cette validation.
