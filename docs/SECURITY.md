# Modèle de sécurité

## Menaces couvertes

| Menace | Protection |
|---|---|
| Écoute du réseau / compromission du relais | AES-256-GCM, clés dérivées par ECDH X25519 + HKDF |
| Vol de l'appareil verrouillé | Données chiffrées par PBKDF2(PIN), clés privées dans le Keystore |
| Substitution de clé (MITM) au moment de l'appairage | Numéro de sécurité à comparer hors-bande |
| Rejeu / modification de messages | Tag d'authentification GCM (16 octets) vérifié au déchiffrement |

## Ce que le relais peut voir

Uniquement : adresses de session temporaires (UUID), horodatages, tailles de paquets.
Jamais le contenu des messages ni les clés.

## Recommandations de déploiement

- Toujours utiliser **wss://** (TLS) en production, jamais `ws://` sur Internet.
- Le relais écoute sur `127.0.0.1` par défaut : à vous de l'exposer via un reverse
  proxy TLS si vous l'héberger vous-même.
- Le code PIN n'est jamais transmis ni stocké en clair ; seul un vérifieur chiffré
  est conservé pour valider le PIN au déverrouillage.
