# Revue Windows et Android — 3 novembre 2026

Revue du code source 0.5.0 sur la base du commit `eb390e3`, complétée par les
corrections locales décrites ci-dessous. Aucune nouvelle release ni modification
des packages Windows/Android existants n’a été publiée pendant cette revue.

## Erreurs reproduites et corrigées

| Parcours | Problème constaté | Correction |
|---|---|---|
| Appairage : nouveau code | Le bouton régénérait le code puis fermait la fenêtre avant de permettre sa lecture. | La fenêtre reste ouverte et affiche le nouveau code. |
| Consultation d’un ancien groupe | L’action « Numéro de sécurité » utilisait un contact inexistant et pouvait provoquer une erreur. | Cette action est réservée aux conversations individuelles. |
| Envoi lent et saisie suivante | Une seconde validation pouvait envoyer deux messages ; la fin du premier envoi effaçait le nouveau brouillon. | Un seul envoi à la fois ; le brouillon n’est effacé que s’il n’a pas changé. |
| Création d’un groupe | Une erreur de sauvegarde remontait sans être traitée par le formulaire. | Erreur visible, bouton réactivé, contrôleur libéré après fermeture. |
| Saisie du code d’appairage | Un code incomplet était envoyé puis le formulaire se fermait, sans retour utile. | Validation locale, normalisation en majuscules et maintien du formulaire en cas d’erreur. |
| Modification du profil | Une erreur de sauvegarde du nom remontait sans être traitée. | Message d’erreur visible. |
| Modification du nom hors ligne | Le nom enregistré changeait, mais le profil gardait l’ancien nom en mémoire. | Mise à jour de la valeur en mémoire après sauvegarde réussie. |

La création de groupe est également défilable avec de nombreux contacts et un
clavier sur un écran de 320 px de large. Les libellés précisent que le transfert
d’un fichier est chiffré, sans prétendre que sa copie locale reste chiffrée.
Le texte de vérification des empreintes ne promet plus une sécurité absolue.

## Vérifications

- `flutter analyze --no-pub` : aucune anomalie après correction.
- `flutter test --no-pub` : 55 tests réussis, dont 8 nouveaux tests ciblés.
- `npm test --prefix server` : 4 tests réussis.
- `npm audit --prefix server --omit=dev --audit-level=high` : aucune vulnérabilité
  signalée par le registre au moment de la revue, pour les dépendances du relais.

Les tests couvrent notamment le protocole réel Flutter/Node, la reconnexion,
la réception différée, les accusés chiffrés, les groupes, le coffre, les erreurs de
stockage simulées et plusieurs parcours d’interface. Les tests de menus tournent
avec Flutter sous Linux : ils ne remplacent pas un essai natif Windows/Android.

## Limites et qualification restante

Cette revue ne garantit pas l’absence de tout bug et n’est pas un audit
cryptographique indépendant. Aucun nouveau binaire Windows/Android n’a été
compilé ou testé sur appareil réel pendant cette revue.

À qualifier avant diffusion des correctifs : installation/mise à jour sur des
appareils Windows et Android, ouverture des pièces jointes via les applications
externes, comportement des opérations de groupe en cas de stockage saturé,
restauration des sauvegardes du relais et charge sur un réseau partagé.

Limites déjà connues, conservées : pas de notifications mobiles à application
fermée, fichiers reçus déchiffrés sur le disque, absence de verrouillage automatique,
absence de signature Authenticode, expiration des paquets du relais après sept
jours, quotas, et limite de vingt connexions par adresse vue par le relais. La
révocation des clés de groupe et l’absence de renouvellement des clés de session
par message nécessitent une étude cryptographique distincte.

L’ancienne revue `PROJECT_REVIEW.md` concerne la version 0.3.6 : certaines de ses
priorités ont déjà été traitées en 0.5.0, notamment l’identité persistante et la
livraison différée.
