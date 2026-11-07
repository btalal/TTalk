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

## Exemple de configuration : Fly.io

Le fichier [`fly.toml`](fly.toml) prépare une machine **permanente**
(`shared-cpu-1x`, 512 Mo, région Paris) avec un volume persistant de 1 Go monté
sur `/data`. Les prix doivent être vérifiés sur la page tarifaire de Fly.io ;
ne validez que si le montant mensuel vous convient.

1. Installer `flyctl` et se connecter : `fly auth login`.
2. Depuis le dossier `server`, créer l’application avec la configuration du
   dépôt : `fly launch --copy-config --no-deploy` (choisir un nom d’application
   libre si `ttalk` est déjà pris, et l’indiquer dans `fly.toml`).
3. Créer le volume : `fly volumes create ttalk_messages --size 1 --region cdg`.
4. Déployer : `fly deploy`.
5. Fly.io fournit une adresse `https://<application>.fly.dev`. Ouvrir `/healthz`
   sur cette adresse : la réponse attendue est `{"status":"ok","protocol":2}`.
6. Dans TTalk, ouvrir **Configurer le serveur**, coller l’adresse HTTPS et
   enregistrer sur chaque appareil avant de les appairer.

Les connexions WSS sont terminées par Fly.io : aucun certificat à gérer sur les
appareils. Les mises à jour du relais sont manuelles (`fly deploy`) pour éviter
de changer le protocole sans mettre à jour les applications.

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
