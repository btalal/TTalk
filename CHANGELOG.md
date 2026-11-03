# Versions

## 0.5.0-preview.9 — Premiers clients Android et iPhone

- Projets Android 7.0+ et iOS 15+ avec la même identité visuelle et le protocole 2
  du relais Windows 0.4 ; chaque appareil dispose de ses propres clés.
- Stockage sécurisé Android Keystore et Trousseau iOS, sauvegarde Android désactivée.
- Menu adapté aux petits écrans, PIN défilant avec le clavier, confidentialité
  à l’inactivité et reconnexion après suspension ; accusés limités à l’écran visible.
- Compilations Android APK et iOS IPA non signés, tests natifs sur émulateur Android
  et simulateur iPhone ; signature séparée avec une clé Android persistante.
- Guide de signature personnelle de l’IPA depuis Windows, sans Mac personnel.

Préversion de développement : pas de notifications APNs/FCM ni de réception
garantie en arrière-plan. L’installation iPhone nécessite une signature Apple ;
les comptes gratuits imposent généralement un renouvellement tous les 7 jours.
Les échanges sur appareils réels et l’hébergement restent à valider.

## 0.4.0-rc.4 — Présentation Windows

- Icône TTalk bleu nuit et violet dans Windows, l’application et le README.
- Thèmes clair et sombre accordés à l’indigo.
- ZIP organisé : lanceur TTalk.exe à la racine, fichiers techniques dans app/.
- Lanceur natif x64 sans console, avec runtime statique et chemins indépendants
  du dossier de travail ; les raccourcis Bureau sont pris en charge.
- Vérification Windows du lancement depuis un chemin avec espaces, depuis un
  autre dossier, et du refus d’une seconde instance via le lanceur.

Cette préversion conserve les limites et la compatibilité de la version 0.4
ci-dessous. L’hébergement réel et les échanges entre deux PC restent à valider.

## 0.4.0-rc.3 — Windows candidate

- Refus d’écriture locale détecté même sans exception ; reprise sans confirmation prématurée.
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
