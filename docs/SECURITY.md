# Modèle de sécurité — TTalk 0.5.1

Mis à jour le **4 novembre 2026**. Ce document décrit les versions stables
Windows et Android 0.5.1 et le relais utilisant le **protocole 2**.
Les versions finales iPhone et Mac 0.5.1 ont été validées pour installation
personnelle via Xcode ; voir [les essais Apple](APPLE_VALIDATION.md).
Les nouvelles protections de la branche 0.6 restent en développement et sont
décrites séparément dans [NEXT_SECURITY.md](NEXT_SECURITY.md).

TTalk chiffre le contenu des échanges de bout en bout. Les protections dépendent
également de la vérification des contacts et de la sécurité des appareils.
Le projet n’est pas une implémentation de Signal/MLS et n’a pas fait l’objet d’un
audit cryptographique indépendant.

## Protections et portée

| Menace | Protection actuelle | Portée et limites |
|---|---|---|
| Écoute du réseau | AES-256-GCM ; clés de session directes dérivées par X25519 et HKDF-SHA256 ; transport HTTPS/WSS. | Le contenu est chiffré ; les métadonnées restent partiellement observables. |
| Modification d’un message chiffré sans sa clé | Vérification du tag GCM de 16 octets et des métadonnées liées au contenu chiffré. | Un paquet altéré est rejeté. Cela ne constitue pas une preuve de l’identité humaine de son auteur. |
| Substitution de clé lors de l’appairage | Empreinte de sécurité calculée à partir des deux clés publiques. | Les participants doivent comparer cette empreinte par un canal fiable ; le code d’appairage seul ne suffit pas. |
| Accès à une copie du coffre local | Chiffrement AES-256-GCM avec une clé dérivée du PIN par PBKDF2-HMAC-SHA256, 210 000 itérations et sel aléatoire. | Un PIN court reste vulnérable à la recherche hors ligne. La protection du système reste nécessaire. |
| Usurpation d’un identifiant auprès d’un relais honnête | Défi éphémère et preuve de possession de la clé privée X25519. | L’identifiant stable est lié à une clé d’appareil ; ce n’est pas une identité civile vérifiée. |
| Coupure pendant la livraison | File locale d’envoi chiffrée, file SQLite du relais et acquittements. | La réception dépend du relais, de la reconnexion, des quotas et de la durée de rétention. |

Un relais compromis peut observer les métadonnées, bloquer ou retarder des
échanges, et tenter de substituer des clés au premier appairage. La vérification
des empreintes est donc essentielle. La protection des groupes après retrait
d’un membre possède une limite supplémentaire décrite ci-dessous.

## Ce que le relais et l’hébergeur peuvent observer

Le relais reçoit notamment :

- les **clés publiques** des appareils et leurs **identifiants stables**, calculés
  par SHA-256 de ces clés ; ces identifiants permettent de relier les reconnexions ;
- le **nom de profil** annoncé lors de l’inscription ;
- les codes d’appairage et les clés publiques échangées pendant cette opération ;
- les identifiants d’expéditeur, de destinataire, de message et, lorsqu’ils sont
  présents, de groupe utilisés pour le routage ;
- les types de paquets, leurs tailles et les horaires observables des échanges.

L’infrastructure d’hébergement peut également observer les adresses IP et les
volumes de trafic, selon sa configuration. TTalk ne garantit pas l’anonymat ni
la confidentialité du graphe des communications vis-à-vis du relais.

En fonctionnement normal, le relais ne reçoit pas le contenu déchiffré des
messages et fichiers, les clés privées d’identité, ni les clés de chiffrement
des conversations. Les surnoms et icônes personnalisés en 0.5.1 restent locaux.

## Coffre local et clés d’identité

Le coffre chiffré contient les conversations, les messages, les groupes, leurs
clés, les envois en attente et les personnalisations locales.

Les **clés d’identité sont conservées séparément**, via le stockage sécurisé du
système : stockage sécurisé Windows, mécanismes reposant sur le Keystore Android,
et Trousseau sur iPhone et macOS. Leur protection dépend du système et
de son état de verrouillage ; elles ne sont pas simplement chiffrées par le PIN.

Le PIN n’est pas transmis au relais ni enregistré en clair. Un vérifieur chiffré
permet de contrôler sa validité. Le sel de dérivation est stocké localement.
Le nom de profil et l’adresse du relais sont des préférences locales enregistrées
sans chiffrement par le PIN.

Choisir un PIN suffisamment long et protéger le compte système et le disque.
Le masquage de l’écran sur mobile en arrière-plan ne remplace pas un verrouillage
du coffre : **le verrouillage automatique n’est pas encore intégré**.
Un appareil compromis ou déjà déverrouillé peut exposer les données accessibles
à l’application. La perte ou la suppression des clés et données peut entraîner
la perte de l’identité et de l’historique.

## Transport et livraison différée

Le protocole 2 authentifie l’inscription de l’appareil par un défi éphémère.
Les messages contiennent, à l’intérieur du chiffrement, l’expéditeur, l’identifiant
du message, le groupe éventuel et la date. Des métadonnées de routage restent
également visibles à l’extérieur du chiffrement. Les accusés entre participants
sont chiffrés.

Un message valide pris en charge par l’application est sauvegardé localement
avant l’acquittement de sa prise en charge auprès du relais. Les erreurs de
stockage permettent une nouvelle tentative. Les paquets invalides peuvent être
rejetés et retirés de la file afin d’éviter des retransmissions sans fin.

La file SQLite du relais conserve des paquets chiffrés et des métadonnées de
routage, avec une **rétention de sept jours par défaut** et des quotas. Après
acquittement, le contenu du paquet est retiré de la file active ; un marqueur de
dédoublonnage est conservé jusqu’à expiration. Les pages SQLite, le journal WAL
et les sauvegardes ne garantissent pas l’effacement physique ou cryptographique
de toutes les traces.

Un accusé de réception ou de lecture représente un état de l’application ; il
ne prouve pas qu’une personne a lu ou compris le message. Sur mobile, la réception
reprend à l’ouverture : les notifications push et la réception permanente en
arrière-plan ne sont pas intégrées.

## Groupes et renouvellement des clés

Les groupes utilisent des clés partagées et des contrôles de membres et de
propriété. Lors du retrait d’un membre, la distribution de la nouvelle clé repose
sur son exclusion par le relais. **La confidentialité des échanges futurs n’est
pas garantie contre une collusion entre ce membre et un relais compromis.**

Les clés de session des conversations directes ne sont pas renouvelées à chaque
message par un mécanisme de ratchet. La compromission ultérieure d’une clé privée
d’identité peut donc permettre de déchiffrer d’anciens échanges directs capturés.
La présence d’un défi éphémère pour l’inscription ne fournit pas cette protection
aux messages.

## Pièces jointes et suppressions locales

Les fichiers sont chiffrés pendant leur transfert, puis **enregistrés en clair
sur le disque de l’appareil destinataire après déchiffrement**. Le PIN du coffre
ne protège pas ces copies externes.

En 0.5.1, supprimer un message ou une conversation efface la copie de l’historique
sur cet appareil. Cette action ne rappelle pas un envoi déjà transmis au relais,
ne supprime pas les copies des autres participants et conserve les fichiers déjà
enregistrés. Quitter et supprimer un groupe le retire de cet appareil ; le groupe
peut continuer pour les autres membres.

Les suppressions ne constituent pas une garantie d’effacement sécurisé du support
ou des sauvegardes. Consulter le [guide des nouveaux menus](CHAT_MANAGEMENT.md).

## Déploiement et intégrité des distributions

- Utiliser **HTTPS/WSS avec un certificat TLS valide** sur Internet. Le client
  refuse les relais distants en HTTP/WS ; le transport non chiffré est réservé
  aux adresses de boucle locale autorisées.
- Le relais écoute sur `127.0.0.1` par défaut. Sur un VPS, utiliser un reverse
  proxy TLS comme Caddy ou Nginx ; sur un hébergement géré, la plateforme peut
  assurer la terminaison TLS.
- Protéger l’accès au serveur, au disque persistant et aux sauvegardes. La file
  d’attente n’est pas une sauvegarde durable des conversations.
- Télécharger les packages depuis les [releases officielles](https://github.com/btalal/TTalk/releases).
  Les sommes SHA-256 permettent de contrôler leur intégrité par comparaison avec
  une valeur de confiance ; elles ne remplacent pas une signature d’éditeur.
- L’APK Android est signé avec la même clé entre les versions 0.5.0 et 0.5.1,
  permettant la mise à jour sans désinstallation. La clé privée de signature
  doit être sauvegardée et conservée hors du dépôt.
- Les exécutables Windows ne disposent pas de signature Authenticode.

## État de validation

Windows et Android 0.5.1 sont publiés en versions stables. Le périmètre précédent
(messages, fichiers, redémarrage, réception différée, groupes et transfert de
propriété) a été confirmé par l’utilisateur sur deux PC Windows x64 et un
smartphone Android.

La publication 0.5.1 a validé 70 tests Flutter, quatre tests du relais, un test
natif Android sur émulateur et les contrôles de lancement et de packaging Windows.
Ces résultats ne remplacent pas un audit cryptographique ni une qualification
sur tous les appareils, versions de système et réseaux d’établissement.
