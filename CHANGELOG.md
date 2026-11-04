# Versions

## 0.3.4

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
