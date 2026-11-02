# Revue du projet — version 0.3.5

Périmètre : code Dart (démarrage, coffre, crypto, état, groupes, interface), relais
Node.js, configuration native Windows, dépendances et publication. Cette revue et
les tests ne constituent pas une certification de sécurité.

## Corrections et optimisations appliquées

- Le démarrage n’attend plus le réseau. La fenêtre de déverrouillage fonctionne
  sans relais et une tentative de connexion échouée reste récupérable.
- Le profil est enregistré auprès du relais après déverrouillage. Le changement
  de nom conserve l’identifiant de la session côté serveur.
- Le déverrouillage charge et déchiffre le coffre une seule fois au lieu de deux.
  La création du PIN évite une deuxième dérivation PBKDF2 immédiate.
- Les écritures chiffrées sont ordonnées. La réception des fichiers ne lance plus
  une sauvegarde intermédiaire avant l’ajout du message à l’historique.
- Réception et lecture sont distinguées, y compris pour les groupes. Les accusés
  répétés ne provoquent plus d’écritures supplémentaires.
- Les doublons d’identifiant de message sont ignorés avant déchiffrement et IO.
- Les primitives AES-GCM sont mutualisées, sans changer le format chiffré existant.
  Les paquets tronqués ou dont le préfixe nonce a changé sont rejetés.
- Les pièces jointes sont limitées à 5 Mo avant chargement complet. Leur nom local
  comporte un UUID pour éviter collisions et écrasements.
- Les connexions concurrentes sont regroupées et les erreurs d’envoi sont visibles.
- Le relais limite les charges à 16 Mo, valide les inscriptions, nettoie les codes
  d’appairage et termine les connexions mortes avec ping/pong.
- La CI conserve le SDK Flutter en cache, utilise le verrouillage npm, analyse
  Dart, teste les deux composants et contrôle le package Windows avant publication.

## Priorités restantes

1. Identité de transport persistante et authentifiée : les IDs actuels changent
   après redémarrage. Une évolution du protocole et une migration des contacts et
   groupes sont nécessaires ; un simple hash public ne suffit pas à authentifier
   une inscription.
2. Authentifier les accusés et lier les métadonnées (groupe, expéditeur, identifiant)
   au contenu chiffré pour renforcer la résistance au rejeu et à un relais hostile.
3. Pour les gros historiques, passer du coffre JSON complet à un stockage chiffré
   incrémental ; la sauvegarde actuelle croît avec l’historique et les pièces jointes.
4. Ajouter des compteurs de version aux changements d’appartenance/propriété pour
   empêcher le rejeu d’anciens contrôles après plusieurs transferts successifs.
5. Livraison hors ligne, révocation explicite côté membre retiré, verrouillage
   automatique du coffre, et option de conservation chiffrée des fichiers reçus.
6. Signature Authenticode et validation manuelle sur une machine Windows 10/11
   propre. Le smoke test CI contrôle le lancement, pas tous les parcours utilisateur.

Aucun gain de débit global n’est revendiqué sans benchmark. Les réductions
indiquées ci-dessus correspondent aux opérations supprimées dans les chemins revus.
