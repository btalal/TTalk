# Modèle de sécurité

## Menaces couvertes

| Menace | Protection |
|---|---|
| Écoute du réseau / compromission du relais | AES-256-GCM, clés dérivées par ECDH X25519 + HKDF |
| Vol de l'appareil verrouillé | Données chiffrées par PBKDF2(PIN), clés privées dans le Gestionnaire d’identifiants Windows |
| Substitution de clé (MITM) au moment de l'appairage | Numéro de sécurité à comparer hors-bande |
| Modification du contenu des messages | Tag d’authentification GCM (16 octets) vérifié au déchiffrement |

## Ce que le relais peut voir

Uniquement : adresses de session temporaires (UUID), horodatages, tailles de paquets.
Jamais le contenu des messages ni les clés.

## Recommandations de déploiement

- Toujours utiliser **wss://** (TLS) en production, jamais `ws://` sur Internet.
- Le relais écoute sur `127.0.0.1` par défaut : à vous de l'exposer via un reverse
  proxy TLS si vous l'héberger vous-même.
- Le code PIN n'est jamais transmis ni stocké en clair ; seul un vérifieur chiffré
  est conservé pour valider le PIN au déverrouillage.

## Limites vérifiées

- Les doublons portant le même identifiant sont ignorés. Le protocole actuel ne
  lie pas cryptographiquement tous les identifiants de transport au contenu :
  il ne fournit pas de protection générale contre le rejeu par un relais malveillant.
- Les accusés de réception/lecture transitent par le relais sans authentification
  de bout en bout. Ils ne constituent pas une preuve de lecture.
- Les fichiers reçus sont enregistrés en clair dans Documents après déchiffrement.
- Les identifiants sont propres à la session du relais. Le redémarrage impose
  un nouvel appairage ; les groupes peuvent devoir être recréés.
- L’application Windows publiée n’a pas de signature Authenticode.
