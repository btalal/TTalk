# Relais TTalk sur un NAS (Asustor) avec Tailscale Funnel

Solution de secours ou d’économie : le relais tourne chez vous, sur le NAS, et
reste joignable depuis Internet en HTTPS grâce à **Tailscale Funnel**.

- Aucun port à ouvrir sur la box, aucun nom de domaine à acheter.
- Adresse publique fournie par Tailscale : `https://ttalk.<votre-tailnet>.ts.net`.
- Le relais n’écoute que dans son conteneur ; il n’est pas exposé sur le réseau local.

Les fichiers sont dans [`server/nas/`](nas/) :
`docker-compose.yml`, `serve.json`, `.env.example`.

## Ce qu’il faut savoir avant

- Le relais dépend de l’électricité, de la box et du débit **montant** de la
  maison. En cas de coupure, les messages restent en attente sur les appareils
  et repartent ensuite.
- Changer de relais fait perdre les messages **pas encore livrés** par l’ancien.
  Basculer à un moment calme, puis changer l’adresse sur **tous** les appareils.
- Tailscale voit les métadonnées de connexion du NAS (comme Fly.io aujourd’hui) ;
  le contenu des messages reste chiffré de bout en bout par TTalk.

## 1. Préparer Tailscale (une seule fois)

1. Créer un compte gratuit sur <https://login.tailscale.com>.
2. Console Tailscale › **DNS** : activer **MagicDNS** et **HTTPS Certificates**.
3. Console › **Access controls** : autoriser Funnel. Tailscale propose un bouton
   pour l’ajouter ; sinon, vérifier que la politique contient :

   ```json
   "nodeAttrs": [
     { "target": ["autogroup:member"], "attr": ["funnel"] }
   ]
   ```

4. Console › **Settings › Keys** : **Generate auth key**. Garder la clé
   (`tskey-auth-…`) pour l’étape 3 ; elle ne s’affiche qu’une fois.

## 2. Installer Docker sur l’Asustor

1. **App Central** : installer **Docker Engine** (Docker Compose v2 inclus).
   Portainer est facultatif.
2. **Services › Terminal** : activer **SSH** (le désactiver à la fin si vous
   ne l’utilisez pas).
3. Avec **File Explorer**, créer le dossier `Docker/ttalk-relay`
   (chemin : `/volume1/Docker/ttalk-relay`).

## 3. Déposer la configuration

Copier dans `/volume1/Docker/ttalk-relay` les trois fichiers de
[`server/nas/`](nas/) :

- `docker-compose.yml`
- `serve.json`
- `.env.example`, renommé en **`.env`**, en remplaçant `tskey-auth-A_REMPLACER`
  par votre clé Tailscale.

## 4. Démarrer

Se connecter en SSH au NAS (`ssh admin@IP-du-NAS`), puis :

```sh
cd /volume1/Docker/ttalk-relay
sudo docker compose up -d --build
sudo docker compose logs -f
```

Le premier démarrage télécharge Tailscale et compile le relais depuis GitHub
(quelques minutes). Dans les journaux, attendre :
`TTalk relay listening on ws://127.0.0.1:8080/ws`.

Le NAS apparaît alors dans la console Tailscale sous le nom **ttalk**. L’adresse
exacte (`ttalk.<tailnet>.ts.net`) y est affichée.

## 5. Vérifier

1. Ouvrir `https://ttalk.<tailnet>.ts.net/healthz` depuis un téléphone **en 4G**
   (hors Wi-Fi de la maison) : la réponse attendue est
   `{"status":"ok","protocol":2}`.
2. Dans TTalk, sur un appareil de test : **Configurer le serveur** › saisir
   `https://ttalk.<tailnet>.ts.net` › le badge **Connecté** doit apparaître.
3. Envoyer un message entre deux appareils configurés sur cette adresse.
   Ce test confirme que Funnel transmet bien la connexion WebSocket du relais.

## 6. Basculer tous les appareils

Quand le test est concluant, saisir la nouvelle adresse dans **Configurer le
serveur** sur chaque appareil (Windows, Mac, Android, iPhone). Les nouvelles
invitations utiliseront cette adresse.

Garder l’ancien relais Fly.io quelques jours, le temps que tout le monde ait
basculé, puis l’arrêter pour ne plus le payer.

## Entretien

- **Mettre à jour le relais** (après une nouvelle version sur GitHub) :

  ```sh
  cd /volume1/Docker/ttalk-relay
  sudo docker compose build --pull relay && sudo docker compose up -d
  ```

- **Sauvegarder** le dossier `/volume1/Docker/ttalk-relay/data` (base SQLite
  des messages en attente) avec **Backup Plan** de l’Asustor.
- **Arrêter** : `sudo docker compose down` (les données restent dans `data/`).
- Le fichier `.env` contient une clé secrète : ne pas le publier ni le
  partager. Après le premier démarrage, la clé n’est plus nécessaire ; l’état
  Tailscale est conservé dans `tailscale-state/`.

## En cas de problème

| Symptôme | Piste |
|---|---|
| `TS_AUTHKEY` manquant au démarrage | Le fichier `.env` n’est pas dans le dossier, ou il s’appelle encore `.env.example`. |
| `/healthz` injoignable depuis la 4G | Funnel non autorisé (étape 1.3) ou certificats HTTPS non activés (étape 1.2). |
| `/healthz` répond mais TTalk reste « Connexion en cours » | Vérifier l’adresse saisie (`https://`, sans `/ws`). Consulter `docker compose logs relay`. |
| Erreur de compilation du relais | Vérifier l’accès Internet du NAS ; relancer `docker compose up -d --build`. |
