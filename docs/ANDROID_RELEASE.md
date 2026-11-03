# TTalk 0.5.0 — Android

Version finale du périmètre validé sur deux PC Windows x64 et un smartphone Android :
messages, fichiers, contacts et historique conservés après redémarrage, réception
différée à la réouverture, groupes et transfert de propriété.

Télécharger **ttalk-android.apk**, le package signé. Installer la mise à jour
par-dessus la préversion, sans désinstaller TTalk, pour conserver les données.
Le package utilise la même clé de signature que la préversion.

Android 7.0 minimum ; ARM64, ARMv7 et x86_64. Une somme SHA256 accompagne l’APK.
L’APK `ttalk-android-unsigned.apk` est un résultat de compilation qui ne s’installe
pas directement ; il ne sert pas à l’installation utilisateur.

Configurer le même relais HTTPS que sur Windows. Les notifications push sont
reportées : la réception reprend à l’ouverture de l’application. Aucune dépendance
Firebase/APNs n’a été ajoutée. iPhone reste en préversion.
