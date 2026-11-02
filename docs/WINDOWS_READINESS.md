# Finalisation Windows — 0.4.0-rc.1

Windows est prioritaire. Android puis iOS seront développés après validation de
l’application et du service Windows en conditions réelles.

## Préparé dans le dépôt

- Configuration du relais sans recompilation, WSS obligatoire hors boucle locale.
- Identité stable issue de la clé X25519, preuve HMAC d’un défi éphémère.
- Coffre conservé ; migration des contacts ; groupes anciens archivés en lecture.
- File d’envoi chiffrée persistante et reprise après reconnexion/redémarrage.
- SQLite côté relais : enregistrement durable avant acceptation, effacement du
  contenu après confirmation du destinataire, reprise et déduplication.
- Invitations et accusés conservés/chiffrés ; horodatage d’origine chiffré.
- Métadonnées liées au contenu, compteur de transfert et limites de charge.
- Déploiement Render décrit dans server/README.md et render.yaml.

## Vérifications requises avant une version finale

1. Créer le service permanent et le disque sur le compte d’hébergement choisi.
   Le prix affiché par le prestataire doit être accepté par le titulaire du compte.
2. Vérifier /healthz, le certificat TLS et la connexion WSS publique.
3. Avec deux PC sur des réseaux distincts : appairage, messages dans les deux sens,
   réception hors ligne, redémarrage des applications et du relais.
4. Tester les pièces jointes, les groupes et les droits sur ces deux PC, puis
   vérifier sauvegarde/restauration du disque du serveur.
5. Valider Windows 10 et Windows 11 propres. La CI vérifie la compilation et
   l’ouverture du ZIP sous Windows Server 2022, pas tous ces parcours matériels.

## Limites conservées

Les paquets expirent après 7 jours et les quotas peuvent retarder les envois.
Les fichiers reçus restent en clair sur le disque après déchiffrement.
La signature Authenticode, le verrouillage automatique du coffre et le chiffrement
optionnel des pièces jointes reçues restent à préparer.
La révocation des clés de groupe actuelle dépend encore de l’exclusion du
membre par le relais ; elle doit être revue cryptographiquement pour résister à
une collusion entre un ancien membre et un relais compromis. Les échanges directs
utilisent des clés de session entre les deux appareils.

Il ne faut pas qualifier la version de totalement finalisée tant que le service
public et les deux PC n’ont pas été validés. Aucun hébergement payant n’a été créé
ou facturé par l’agent.
