# TTalk 0.6 — développement et validation

Cette branche prépare les améliorations approuvées le 6 novembre 2026.
Elle n’est pas une nouvelle version finale. Les versions finales 0.5.1 restent
les références pour les installations existantes.

## Fonctions réalisées dans cette branche

- Mac/Windows : navigation latérale, liste et conversation simultanées à partir
  de 960 pixels ; recherche locale dans noms, messages et noms de fichiers.
- iPhone/Android : navigation basse Discussions, Contacts et Réglages ; filtres
  Groupes, Non lues et Archives. Aucun message n’est envoyé à un service de recherche.
- Épinglage et archivage locaux persistants, distincts des suppressions.
- Invitations QR et liens `ttalk://pair` copiables/collables. Scanner sur mobile
  et Mac ; saisie et collage disponibles sur Windows. L’ouverture automatique
  d’un lien depuis une autre application n’est pas encore enregistrée sur les OS.
- Les invitations incluent l’adresse du relais et l’identité attendue. Un lien
  ne change jamais silencieusement le relais et ne vérifie pas à lui seul le contact.
- Réponse citée, réactions chiffrées avec détection préalable d’une version
  compatible et suppression d’une réaction par son auteur. Les anciennes versions
  continuent à lire le texte des réponses ; elles ne prennent pas en charge les réactions.
- Bulles de largeur limitée, dates, rédaction multiligne, menu sur appui long ou
  clic secondaire. Entrée envoie sur ordinateur, Maj+Entrée ajoute une ligne.
- Verrouillage manuel (Ctrl/Cmd+L) et automatique (30 s, 1, 5 ou 15 minutes).
  Le coffre est déchargé et la connexion fermée. Le masquage d’arrière-plan reste actif.
- Déverrouillage biométrique facultatif sur iOS, Android et Mac pris en charge :
  clé du coffre protégée par la biométrie Keychain/Keystore, sans sauvegarder le PIN.
  Le PIN reste utilisable ; aucun déverrouillage biométrique non protégé sur Windows.
- Sauvegarde locale chiffrée par une phrase de passe indépendante de 16 caractères
  minimum. Identité, historique et clés inclus ; pièces jointes et envois en attente
  exclus. Restauration réservée à un coffre vide et à une seule identité active.

## Compatibilité et sécurité

Le relais reste au protocole 2. Les extensions de réponse sont dans l’enveloppe
chiffrée ; les réactions sont bloquées tant qu’un échange chiffré n’a pas annoncé
leur prise en charge par chaque contact. Le partage de nouvelle clé après retrait
d’un membre exige des sessions individuelles et la prise en charge des membres
restants. Les rotations sous l’ancienne clé collective sont refusées.

Cela ne remplace pas un ratchet ni un audit. Voir [la revue de sécurité](NEXT_SECURITY.md).
Les sauvegardes ne sont pas une synchronisation entre appareils. Cesser d’utiliser
l’ancien appareil avant de restaurer son identité ; aucune fusion d’historiques.
Un renouvellement de sauvegarde n’invalide pas automatiquement les copies précédentes.

## Validation avant diffusion

- Analyse Dart et tests automatisés : voir le workflow **Validate next TTalk clients**.
- Vérifier les compilations Release iPhone, macOS, Android et Windows.
- Essais réels encore nécessaires pour caméra, refus d’autorisation, Face ID/Touch ID,
  changement d’empreintes, PIN de secours, verrouillage après suspension, refus de
  sauvegarde, import interrompu, réinstallation sans désinstallation et compatibilité 0.5.1.
- Essayer la rotation avec un groupe à trois appareils, un destinataire hors ligne,
  un membre retiré et les envois en attente.
- Captures des quatre plateformes à produire sur les versions effectivement testées.

Les notifications push sont **reportées à la demande du propriétaire**. Aucun SDK
Firebase, jeton push, serveur de notification ou abonnement Apple n’est ajouté ici.
Les appels, messages vocaux et synchronisation multiappareil restent hors de ce lot.
