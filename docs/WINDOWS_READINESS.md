# Validation Windows et Android — 0.5.0

La version 0.5.0 est publiée en finale pour Windows x64 et Android, sur le
périmètre fonctionnel validé. Cette note décrit les essais du 3 novembre 2026.
Depuis le 6 novembre, [iPhone et macOS sont également disponibles en versions
finales](https://github.com/btalal/TTalk/releases/tag/v0.5.1-apple), avec compilation
et signature personnelle dans Xcode.

## Essais confirmés par l’utilisateur le 3 novembre 2026

Sur deux PC Windows x64 et un smartphone Android :

- Envoi et réception des messages et des fichiers.
- Contacts et historique conservés après redémarrage des applications.
- Message envoyé au téléphone déconnecté reçu à la réouverture.
- Groupe avec les trois appareils et transfert de propriété.

Ces résultats sont rapportés par l’utilisateur ; les versions précises de Windows
et les caractéristiques du téléphone n’ont pas été communiquées.

## Contrôles automatisés

La CI analyse et teste le code commun et le relais. Elle ouvre le ZIP Windows
extrait sous Windows Server 2022, vérifie son organisation, les binaires x64 et
le refus d’une seconde instance. Le test Android s’exécute sur émulateur et
vérifie l’identité persistante, le PIN, le coffre et la file d’envoi.
Les signatures Android et les sommes SHA256 sont vérifiées avant publication.

## Qualification à poursuivre selon le déploiement

Les essais confirmés ne remplacent pas une qualification de toutes les
installations Windows 10/11 et de tous les téléphones, ni un audit cryptographique
indépendant. La sauvegarde/restauration du disque du relais et la surveillance
opérationnelle dépendent de l’hébergement choisi et restent à vérifier sur celui-ci.

Les notifications mobiles sont volontairement reportées : aucun SDK Firebase/APNs
n’a été ajouté. La réception reprend quand l’application est ouverte.

## Limites conservées

Les paquets expirent après 7 jours et les quotas peuvent retarder les envois.
Les fichiers reçus restent en clair sur le disque après déchiffrement.
La signature Authenticode, le verrouillage automatique du coffre et le chiffrement
optionnel des pièces jointes reçues restent à préparer.
La révocation des clés de groupe actuelle dépend encore de l’exclusion du
membre par le relais ; elle doit être revue cryptographiquement pour résister à
une collusion entre un ancien membre et un relais compromis. Les échanges directs
utilisent des clés de session entre les deux appareils.
