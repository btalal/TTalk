# Publication des APK signés hors CI

La clé privée Android reste hors du dépôt et hors des runners GitHub.
L’APK est signé localement, puis comparé à l’APK non signé déjà compilé et testé.
Le correctif BSDIFF contient uniquement la différence entre ces deux fichiers
publics : signatures, certificat public et métadonnées ZIP. Il ne contient pas
la clé privée ni son mot de passe.

Le manifeste identifie la release source, les sommes SHA256 des deux APK et du
correctif, ainsi que l’empreinte du certificat. Le workflow reconstruit l’APK,
vérifie chaque somme et la signature Android avant de le publier.

Pour une prochaine version, signer avec le même keystore privé, générer le
correctif et son manifeste, puis les ajouter à ce dossier. Ne jamais y déposer
le keystore, sa configuration privée ou sa sauvegarde.
