# Relais TTalk — hébergement

Ce serveur Node.js est fourni dans le dépôt. Les appareils qui échangent
utilisent la même adresse HTTPS. Le relais transporte des paquets chiffrés et
leurs métadonnées de routage ; voir le [modèle de sécurité](../docs/SECURITY.md).

> **Sur un NAS à la maison** (Asustor, Synology, QNAP…), sans ouvrir de port :
> voir le [guide NAS avec Tailscale Funnel](NAS.md).

## Déployer sur un hébergement au choix

Il faut **Node.js 24**, un disque persistant pour la base SQLite, une terminaison
HTTPS/WSS avec certificat valide et un seul processus utilisant cette base.
Configurer `HOST=0.0.0.0` chez l’hébergeur, `PORT` selon sa plateforme et
`DATA_DIR` sur le disque persistant. Depuis `server` :

```sh
npm ci
npm test
npm start
```

Vérifier ensuite `https://votre-relais/healthz` : la réponse attendue est
`{"status":"ok","protocol":2}`. Dans chaque application TTalk, saisir
l’adresse HTTPS dans **Configurer le serveur**. Le chemin WebSocket `/ws` est
ajouté par le client.

## Exemple de configuration : Render

Le fichier `render.yaml` à la racine prépare un service Node.js **permanent** avec
un disque persistant de 1 Go. Le service gratuit qui s’endort n’est pas utilisé.
Les prix et taxes doivent être vérifiés sur l’écran de création de Render ; ne
validez une commande que si son montant mensuel vous convient.

1. Créer un compte sur https://render.com et choisir **New → Blueprint**.
2. Connecter le dépôt public `btalal/TTalk`, branche
   la branche par défaut du dépôt (`main/ttalk`), puis sélectionner le fichier `render.yaml`.
3. Vérifier le service Starter, le disque de 1 Go et le montant facturé, puis
   lancer le déploiement. Aucun secret d’application n’est à saisir.
4. Render fournit une adresse `https://…onrender.com`. Ouvrir `/healthz` sur cette
   adresse : la réponse attendue est `{"status":"ok","protocol":2}`.
5. Dans TTalk, ouvrir **Configurer le serveur**, coller l’adresse HTTPS et
   enregistrer sur chaque appareil avant de les appairer.

Les connexions WSS sont terminées par Render : aucun certificat à gérer sur les PC.
Les mises à jour du service sont manuelles pour éviter de changer le protocole
sans mettre à jour les applications. **Le blueprint préparé n’est pas la preuve
d’un déploiement réussi** : l’accès public et les deux PC restent à valider une
fois le compte et le service créés.

## Développement local

Node.js 24 requis. Depuis `server` :

```powershell
npm ci
npm test
npm start
```

Saisir `http://localhost:8080` dans les paramètres de TTalk ; le chemin `/ws` est
ajouté automatiquement. Cette adresse locale sert uniquement aux tests sur le
même PC. Les serveurs distants doivent utiliser HTTPS/WSS.

## Données et limites

- `PORT` : port du service, 8080 par défaut.
- `HOST` : interface d’écoute, `127.0.0.1` par défaut, `0.0.0.0` chez l’hébergeur.
- `DATA_DIR` : disque persistant, `server/data` si le serveur est lancé depuis
  `server`, `/var/data` dans le blueprint.
- SQLite conserve les paquets chiffrés jusqu’à confirmation de stockage par
  l’application destinataire, ou expiration **7 jours** après leur dépôt.
- Une reconnexion ne change pas l’identité, qui est liée à la clé de l’appareil.
  La connexion prouve la possession de la clé privée avec un défi X25519/HMAC.
- Plafonds : 32 Mo de contenu en attente par destinataire, 256 Mo au total,
  100 000 entrées de déduplication, 16 Mo par trame, 100 destinataires par envoi,
  20 connexions par adresse socket et 600 requêtes/minute/connexion.
- Les accusés et les contrôles de groupe sont chiffrés par les clients. Le relais
  voit néanmoins les identifiants de routage, horaires, volumes et clés publiques.
- Après confirmation, le contenu est retiré de la file ; un marqueur temporaire
  évite une double livraison. L’expiration et les sauvegardes du disque ne sont
  pas un effacement cryptographique garanti des anciennes pages SQLite.
- Prévoir des sauvegardes du disque et une surveillance de sa disponibilité.
  Un seul processus serveur doit utiliser cette base ; pas de montée en charge
  horizontale automatique avec un disque local.
