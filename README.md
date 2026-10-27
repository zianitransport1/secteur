# Ma tournée

Page chauffeur : carte du secteur, rues à faire / faites, suivi GPS.
Lien personnel : `https://zianitransport1.github.io/secteur/?k=CLE_DU_CHAUFFEUR`

## App iPhone « Ziani Transport » (TestFlight)

Le dossier `app/` transforme cette même page en app iPhone. Différences avec la page web :
- le GPS continue **écran verrouillé** (plus besoin de garder l'écran allumé) ;
- au premier lancement, le chauffeur colle son lien personnel, il est ensuite mémorisé.

La page web continue de fonctionner comme avant.

### Mise en place (une seule fois)

1. **App Store Connect** > Apps > « + » > Nouvelle app : plateforme iOS, nom « Ziani Transport »,
   identifiant de lot `com.zianitransport.matournee` (s'il n'apparaît pas dans la liste, le créer dans
   developer.apple.com > Certificates, IDs & Profiles > Identifiers), SKU : `matournee`.
2. **App Store Connect** > Utilisateurs et accès > Intégrations > Clés d'API App Store Connect :
   générer une clé avec le rôle **Admin**, télécharger le fichier `AuthKey_XXXX.p8` (téléchargeable une seule fois),
   noter le **Key ID** et l'**Issuer ID**.
3. **developer.apple.com** > Account > Membership : noter le **Team ID**.
4. **GitHub** > ce dépôt > Settings > Secrets and variables > Actions > New repository secret :
   `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (coller tout le contenu du .p8).

### Publier une version

GitHub > Actions > « App iPhone → TestFlight » > Run workflow (≈ 15-20 min),
puis la version apparaît dans TestFlight après le traitement Apple (15-30 min).

### Inviter les chauffeurs

App Store Connect > l'app > TestFlight : créer un groupe de testeurs **externes** et activer le **lien public**,
ou ajouter des testeurs internes. Le chauffeur installe « TestFlight » depuis l'App Store puis ouvre le lien.
Une version TestFlight expire après 90 jours : relancer le workflow pour en publier une nouvelle.

## Page admin

`https://zianitransport1.github.io/secteur/admin.html` : avancement en direct de tous les secteurs de la semaine,
bonus par chauffeur (synchronisé avec la case « Bonus couverture » de Notion) et réouverture d'un secteur clôturé.
Protégée par un code administrateur (demandé à la première ouverture, puis mémorisé sur l'appareil).
Serveur : workflow n8n « Ma tournée — Suivi en direct & admin » (webhook `tournee-suivi`), table « Avancement tournées ».
