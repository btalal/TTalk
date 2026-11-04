# Versions

## 0.4.0-rc.1 — Windows candidate

- Serveur HTTPS/WSS configurable dans l’interface, sans recompilation.
- Identité persistante avec preuve de possession de la clé X25519 à la connexion.
- Contacts conservés après redémarrage ; migration des anciens contacts par leur clé.
- File d’envoi locale chiffrée, restauration des invitations et reprise automatique.
- Relais SQLite persistant : livraison après redémarrage, confirmations après stockage,
  déduplication et expiration à 7 jours, avec quotas de stockage.
- Métadonnées et accusés chiffrés ; protection contre le réétiquetage des paquets.
- Compteur de propriété pour rejeter les anciens transferts rejoués.
- Blueprint Render avec service permanent, HTTPS et disque persistant.

Préversion : l’hébergement réel et l’échange entre deux PC distants restent à valider.
Les applications et le relais 0.3.6 ne sont pas compatibles avec le nouveau transport.
Les anciens groupes restent lisibles mais doivent être recréés ; l’historique et le PIN
ne sont pas effacés. Android et iOS ne sont pas ajoutés à cette version.

## 0.3.6

- Groupes : transfert de propriété avec confirmation et événements d’arrivée chiffrés.
- Démarrage de l’interface même si le relais est indisponible ; reconnexion contrôlée.
- Enregistrement du profil auprès du relais après déverrouillage, nom personnalisable.
- Accusés de réception et de lecture distincts, prise en charge des lectures de groupe.
- Chargement du coffre sans déchiffrement redondant et écritures ordonnées.
- Fichiers limités à 5 Mo, noms de destination uniques et erreurs d’envoi visibles.
- Relais : nettoyage des codes d’appairage, contrôle des connexions et limite de charge.
- Windows x64 : dépendances MSVC incluses, vérification de l’archive, test de démarrage
  hors ligne et somme SHA256 avant publication.

Le relais reste nécessaire. Pas de livraison hors ligne ni de conservation des
identifiants de session après redémarrage. Les fichiers reçus sont enregistrés en
clair après déchiffrement. Les participants doivent utiliser cette version et son relais.
