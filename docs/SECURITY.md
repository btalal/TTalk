# Modèle de sécurité

## Menaces couvertes

| Menace | Protection |
|---|---|
| Écoute du réseau / compromission du relais | AES-256-GCM, clés dérivées par ECDH X25519 + HKDF |
| Vol de l'appareil verrouillé | Données chiffrées par PBKDF2(PIN), clés privées dans le Gestionnaire d’identifiants Windows |
| Substitution de clé (MITM) au moment de l'appairage | Numéro de sécurité à comparer hors-bande |
| Modification du contenu des messages | Tag d’authentification GCM (16 octets) vérifié au déchiffrement |

## Ce que le relais peut voir

Uniquement : adresses de session temporaires (UUID), horodatages, tailles de paquets.
Jamais le contenu des messages ni les clés.

## Recommandations de déploiement

- Toujours utiliser **wss://** (TLS) en production, jamais `ws://` sur Internet.
- Le relais écoute sur `127.0.0.1` par défaut : à vous de l'exposer via un reverse
  proxy TLS si vous l'héberger vous-même.
- Le code PIN n'est jamais transmis ni stocké en clair ; seul un vérifieur chiffré
  est conservé pour valider le PIN au déverrouillage.

## Transport Windows 0.4 candidat

Le serveur vérifie la possession de la clé X25519 à l’aide d’un défi éphémère et
fournit un identifiant stable égal au SHA256 de la clé publique. Les métadonnées
(expéditeur, groupe, identifiant, date) et les accusés sont à l’intérieur du
contenu chiffré. Le destinataire ne confirme la prise en charge au relais qu’après
le traitement et la sauvegarde locale. Les paquets invalides sont rejetés.

Les clés et l’historique restent locaux. La file SQLite du relais contient des
paquets chiffrés, des identifiants de routage et des horaires. Son délai de
rétention est de 7 jours, avec quotas ; les sauvegardes et les pages SQLite ne
constituent pas un effacement cryptographique garanti.

## Limites

- Le code n’est pas une implémentation de Signal/MLS et n’a pas de certification
  de sécurité. Un audit cryptographique indépendant reste utile.
- La révocation actuelle d’un membre de groupe repose sur l’exclusion de transport
  par le relais pour la distribution de la nouvelle clé. Elle ne garantit pas la
  confidentialité future contre une collusion ancien membre/relais compromis.
- Les fichiers reçus sont enregistrés en clair dans Documents après déchiffrement.
- Un accusé chiffré indique un état de l’application, pas l’attention humaine.
- Conserver les données et clés Windows. Leur suppression change l’identité.
- Pas de signature Authenticode ; la somme SHA256 contrôle le téléchargement.
- L’hébergement public et les tests entre deux réseaux restent à réaliser avant
  de promouvoir la version candidate.
