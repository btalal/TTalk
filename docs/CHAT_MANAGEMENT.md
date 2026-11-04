# Gestion des conversations et personnalisation

Ces fonctions sont disponibles dans les versions Windows et Android 0.5.1.
Elles complètent la version 0.5.0 sans changer le relais ni le protocole.

## Noms et icônes

Le menu **⋮** d’un contact ou d’un groupe propose **Nom et icône**. Le même menu
est accessible dans la barre supérieure d’une conversation.

- Le nom personnalisé et l’icône sont personnels : ils ne changent pas le profil
  ni l’affichage des autres participants.
- Une galerie de vingt symboles est intégrée ; elle ne demande aucune permission,
  aucun téléchargement d’image et aucune nouvelle dépendance.
- Le nom d’origine et la clé du contact restent conservés. Une personnalisation
  ne change pas son identité ni son numéro de sécurité.
- Les choix sont conservés dans le coffre chiffré, après redémarrage, et lors des
  changements de rôle dans un groupe.

## Supprimer et effacer

| Action | Effet sur cet appareil | Ce qui reste conservé |
|---|---|---|
| Message → ⋮ → Supprimer pour moi | Retire le message de votre historique. | Copies des autres participants et fichiers enregistrés. |
| Contact → ⋮ → Supprimer la conversation | Efface l’historique et masque la conversation. | Le contact, accessible dans l’onglet Contacts. |
| Contact → ⋮ → Supprimer le contact | Retire le contact, sa conversation et ses clés de session locales. | Les groupes communs et leurs clés. |
| Groupe → ⋮ → Effacer l’historique | Efface les messages locaux. | Votre participation au groupe. |
| Groupe → ⋮ → Quitter et supprimer | Quitte le groupe et retire son historique local. | Le groupe et les copies des autres membres. |

Chaque suppression demande confirmation. Les originaux des fichiers envoyés et
les fichiers reçus déjà déchiffrés ne sont pas supprimés du disque.

Les messages effacés ne sont pas recréés lors d’une retransmission de leur même
identifiant par le relais. Les nouveaux messages peuvent faire réapparaître une
conversation masquée tant que le contact est conservé.

Un envoi encore présent uniquement dans la file locale peut être annulé. Un
message déjà confié au relais ou reçu par un contact ne peut pas être rappelé.
Effacer un historique ne supprime pas les changements de membres/propriété en
attente de transmission.

Si le propriétaire quitte un groupe, les règles existantes transmettent la
propriété à un membre restant. Pour choisir ce membre explicitement, transférer
la propriété avant de quitter. Un groupe ancien incompatible peut être supprimé
localement sans tentative de notification.

## Contacts et groupes

L’onglet **Contacts** permet de retrouver un contact après la suppression de sa
conversation et de lui écrire à nouveau. Supprimer un contact ne le retire pas
des groupes communs ; le retrait d’un membre reste une action distincte du menu
d’administration du groupe.

## Vérification

Les tests couvrent les confirmations sur petit écran, la personnalisation,
la restauration, les retransmissions après suppression, la conservation des
fichiers originaux, le transfert de propriété à la sortie et les annulations
d’opérations en cas d’échec de sauvegarde. Des essais sur appareils Windows et
Android réels restent nécessaires avant publication des nouveaux packages.
