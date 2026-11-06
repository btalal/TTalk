# Versions

## 0.6.0 — 6 novembre 2026

- Navigation adaptative Mac/Windows à deux colonnes, navigation basse mobile,
  recherche locale et filtres ; épinglage et archives persistants.
- Invitations QR et liens copiables, réponses citées et réactions chiffrées
  conditionnées par la compatibilité des contacts.
- Verrouillage manuel/automatique et biométrie facultative Keychain/Keystore ;
  sauvegarde à phrase de passe indépendante et restauration dans un coffre vide.
- Enveloppement individuel des nouvelles clés lors du retrait d’un membre ;
  refus des rotations avec un client incompatible ou sous l’ancienne clé collective.
- Tests de régression et vérification native des quatre plateformes dans une PR.
- Documentation de contribution et sécurité, formulaires de signalement et de PR.

Notifications push reportées. Ni Double Ratchet ni audit indépendant annoncés par ce lot. Les essais fonctionnels
sur les quatre plateformes sont confirmés par le propriétaire. Voir [la portée](docs/NEXT_VERSION.md).

## 0.5.1 — iPhone et macOS, versions finales (6 novembre 2026)

- Essais manuels confirmés par le propriétaire sur iPhone 17 Pro sous iOS 27.2
  et Mac mini M4 : connexion au relais, ajout de contacts, envoi et réception
  des messages ; lancement autonome après installation Release.
- Sur Mac : application copiée dans Applications et messages reçus conservés
  après fermeture et réouverture.
- Ajout du projet natif macOS validé : icône TTalk commune à iPhone, accès réseau
  sortant et configuration du Trousseau ; aucun compte Apple personnel versionné.
- Guides Xcode pour les deux plateformes, sélection de la Personal Team et du
  mode Release, résolution des outils Flutter Intel sur Mac Apple Silicon.
- Publication finale pour installation avec signature personnelle. Les archives
  CI restent non signées ; pas de notarisation Mac, App Store ou TestFlight.

Le protocole 2 et le code de messagerie restent inchangés. Les groupes, fichiers,
notifications et autres scénarios non essayés sur Apple ne sont pas annoncés
comme validés par ces essais. Voir [le compte rendu](docs/APPLE_VALIDATION.md).

## 0.5.1 — Gestion des conversations et personnalisation

- Suppression locale des messages, conversations et contacts avec confirmation.
- Effacement de l’historique des groupes et action « Quitter et supprimer ».
- Onglet Contacts pour conserver un contact après suppression de la conversation.
- Noms personnalisés et galerie d’icônes pour les contacts et groupes, conservés
  dans le coffre chiffré et visibles uniquement sur cet appareil.
- Protection contre la réapparition des messages supprimés lors des retransmissions.
- Conservation des fichiers déjà enregistrés et des contrôles de groupe en attente.
- Correctifs de menus et formulaires : code d’appairage renouvelé visible,
  validation des codes, protection contre le double envoi et la perte d’un
  brouillon, erreurs de sauvegarde visibles et nom modifié hors ligne actualisé.


## 0.5.0 — Windows et Android, versions finales

- Promotion du périmètre validé sur deux PC Windows x64 et un smartphone Android :
  messages et fichiers, contacts et historique après redémarrage, réception différée,
  groupes à trois appareils et transfert de propriété.
- Android : APK signé avec la même clé que la préversion pour permettre la mise
  à jour en conservant les données ; numéro de version Android augmenté à 24.
- Windows : ZIP portable x64 organisé avec TTalk.exe et son dossier app/.
- Aucune fonction ni dépendance de notifications ajoutée : ce développement est reporté.

Le protocole du relais reste inchangé (protocole 2). iPhone reste en préversion.
La réception mobile reprend à l’ouverture de l’application ; pas de notifications push.


## 0.5.0-preview.11 — Premiers clients Android et iPhone

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
