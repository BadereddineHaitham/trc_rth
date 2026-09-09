# DOCUMENT DE PASSATION DE PROJET (HANDOVER GUIDE)
# APPLICATION TRC RTH — SONATRACH

**Projet** : Gestion du Parc RTH, Équipements Fixes (USD / Pompes), Maintenance & Traçabilité  
**Auteur initial** : Haitham Badereddine  
**Date de passation** : Septembre 2026  
**Statut du projet** : Production / Opérationnel (Web & Android)

---

## 1. VUE D'ENSEMBLE DU PROJET

L'application **TRC RTH** est une solution complète multiplateforme (Web, Android, iOS) développée avec **Flutter** et adossée à une base de données cloud **Supabase (PostgreSQL)**. Elle permet aux équipes de Sonatrach d'assurer :
1. La gestion et le suivi en temps réel du parc de véhicules d'intervention (22 véhicules).
2. L'inventaire et l'inspection des équipements embarqués (150 équipements) et des équipements fixes USD / Pomperie (39 équipements).
3. Le suivi rigoureux des opérations de maintenance (220 enregistrements).
4. Le système d'alertes préventives (visites techniques, épreuves hydrauliques, recharges extincteurs) (33 alertes).
5. La traçabilité intégrale de toutes les actions via des journaux d'audit (Audit Logs).
6. L'export et l'impression de rapports d'inspection et fiches de vie en PDF (optimisé pour Web, Android et iOS Safari).

---

## 2. ACCÈS RAPIDES & LIENS CLÉS

| Composant | Lien / Emplacement |
| :--- | :--- |
| **Dépôt GitHub** | `https://github.com/BadereddineHaitham/trc_rth.git` |
| **Branche Principale (Code source)** | `main` |
| **Branche Déploiement Web** | `gh-pages` |
| **Application Web Live (GitHub Pages)** | **`https://badereddinehaitham.github.io/trc_rth/`** |
| **Fichier APK Android (Installable)** | Déjà compilé sur le bureau : `C:\Users\Pc\Desktop\trc_rth_release.apk` |
| **Code d'Accès du Parc (Scan QR / Manuel)** | **`HSE`** |

---

## 3. BASE DE DONNÉES SUPABASE & IDENTIFIANTS API

Le backend repose sur un projet managé **Supabase (PostgreSQL)** :
- **Dashboard Supabase** : [https://supabase.com/dashboard/project/jddmfpndryodiktulvnc](https://supabase.com/dashboard/project/jddmfpndryodiktulvnc)
- **Project Reference ID** : `jddmfpndryodiktulvnc`
- **Project URL** : `https://jddmfpndryodiktulvnc.supabase.co`
- **Clé Publique Anon (`anonKey`)** :
  ```text
  eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpkZG1mcG5kcnlvZGlrdHVsdm5jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3Mzg2NzYsImV4cCI6MjEwNDMxNDY3Nn0.52U3yQyBm_0VQkwAY4Y-3B_Unuy1_QBy-ccXPkJCopA
  ```
- **Publishable Key** : `sb_publishable_G0pA2-UtWh4uCRxcUduj5Q_5APIusUP`

*(Ces clés sont déjà intégrées dans le code de l'application dans `lib/services/supabase_service.dart` et `lib/main.dart`)*.

---

## 4. COMPTES UTILISATEURS TESTÉS & ACTIFS

Tous les comptes ont été testés et validés avec succès sur l'authentification Supabase :

| Identifiant / Email | Mot de passe | Rôle attribué | Nom affiché |
| :--- | :--- | :--- | :--- |
| `superadmin@sonatrach.dz` | `superadmin@2026` | Super Admin | Super Admin |
| `khoudja@sonatrach.dz` | `KHOUDJA@2026` | Super Admin / HSE | KHOUDJA MED ZOUHIR |
| `sif@sonatrach.dz` | `FERROUDJ@2026` | Super Admin / HSE | Sif FERROUDJ |
| `hafiane@sonatrach.dz` | `hafiane@2026` | Super Admin / HSE | HAFIANE ABDELBAKI |
| `boukerram@sonatrach.dz` | `boukerram@2026` | Super Admin / HSE | ALLAOU BOUKERRAM |
| `walidsoltani@2026` | `walid@2026` | Super Admin / HSE | walid soltani |

> [!TIP]
> **Procédure de réinitialisation de mot de passe en SQL** :  
> Dans Supabase, les mots de passe sont hachés avec l'extension `pgcrypto` dans le schéma `auth.users`. Si un mot de passe doit être modifié manuellement via l'éditeur SQL du dashboard :
> ```sql
> UPDATE auth.users 
> SET encrypted_password = extensions.crypt('NOUVEAU_MOT_DE_PASSE', extensions.gen_salt('bf', 10))
> WHERE email = 'email@sonatrach.dz';
> ```

---

## 5. ARCHITECTURE DU CODE SOURCE

Le projet est structuré selon les standards Flutter :
```text
trc_rth/
├── android/                   # Configuration native Android (manifest, build.gradle, icons)
├── web/                       # Fichiers d'hébergement Web (index.html, manifest.json)
├── lib/
│   ├── main.dart              # Point d'entrée, initialisation Supabase & routes
│   ├── models/                # Modèles de données Dart
│   │   ├── vehicle.dart
│   │   ├── fixed_equipment.dart
│   │   ├── maintenance_record.dart
│   │   ├── alert_item.dart
│   │   └── user_profile.dart
│   ├── screens/               # Interfaces utilisateurs
│   │   ├── auth/              # Écrans de Login & Code Parc ('HSE')
│   │   ├── dashboard_screen.dart # Tableau de bord principal avec statistiques
│   │   ├── vehicles_screen.dart  # Liste et détails des véhicules
│   │   ├── fixed_equipment_screen.dart # Équipements fixes (USD / Pompes)
│   │   ├── maintenance_screen.dart     # Suivi des opérations de maintenance
│   │   ├── alerts_screen.dart          # Alertes d'expiration & échéances
│   │   └── admin_screen.dart           # Gestion utilisateurs & Audit Logs
│   ├── services/              # Services backend et utilitaires
│   │   ├── supabase_service.dart # Toutes les requêtes et opérations CRUD Supabase
│   │   ├── auth_service.dart     # Gestion session utilisateur & droits
│   │   └── pdf_service.dart      # Génération de rapports PDF et compatibilité impression iOS
│   └── widgets/               # Composants graphiques réutilisables (cartes, badges, boutons)
└── pubspec.yaml               # Dépendances Flutter (supabase_flutter, pdf, printing, etc.)
```

---

## 6. SCHÉMA DE LA BASE DE DONNÉES

La base PostgreSQL contient 10 tables principales sous le schéma `public` :

1. **`parks`** : Données des parcs. Contient l'enregistrement unique du parc RTH avec `qr_code = 'HSE'`.
2. **`vehicles`** (22 lignes) : Flotte de véhicules d'intervention (code, type, immatriculation, kilométrage, statut).
3. **`equipment_definitions`** (105 lignes) : Catalogue de référence des types d'équipements de sécurité et d'intervention.
4. **`vehicle_equipment`** (150 lignes) : Équipements actuellement affectés et présents dans chaque véhicule.
5. **`fixed_equipment`** (39 lignes) : Équipements stationnaires (Unité Sécurité Dépot - USD, Pomperie, vannes, etc.).
6. **`maintenance_records`** (220 lignes) : Historique complet des travaux de maintenance, vidanges, contrôles techniques.
7. **`alerts`** (33 lignes) : Alertes actives déclenchées (échéances proches ou dépassées, gravité critique/moyenne).
8. **`user_profiles`** (21 lignes) : Profils applicatifs des agents et administrateurs avec leurs privilèges.
9. **`audit_logs`** (78 lignes) : Journalisation immuable de chaque action (création, modification, suppression).
10. **`system_settings`** : Configuration générale de l'application.

---

## 7. GUIDE DES COMMANDES DE DÉVELOPPEMENT & DÉPLOIEMENT

### A. Lancer l'application en local (Développement)
Ouvrir un terminal PowerShell dans le dossier `c:\Users\Pc\Desktop\trc_rth\trc_rth` :
```powershell
# Récupérer les dépendances
flutter pub get

# Tester dans le navigateur Google Chrome
flutter run -d chrome

# Ou tester sur émulateur / appareil Android branché
flutter run
```

### B. Compiler une nouvelle version APK Android
Pour générer un fichier APK autonome prêt à être installé sur les téléphones du personnel :
```powershell
flutter build apk --release
```
Le fichier généré se trouvera dans :  
`build/app/outputs/flutter-apk/app-release.apk`  
*(Copiez-le simplement sur le Bureau ou partagez-le par câble / WhatsApp / Google Drive)*.

### C. Mettre à jour l'application Web (Déploiement GitHub Pages)
Pour publier toute modification sur le Web :
```powershell
# 1. Compiler le code Web
flutter build web --release --base-href "/trc_rth/"

# 2. Déployer sur la branche gh-pages
cd build/web
git init
git checkout -B gh-pages
git add .
git commit -m "Deploy update to gh-pages"
git remote add origin https://github.com/BadereddineHaitham/trc_rth.git
git push -f origin gh-pages
cd ../..
```
Le site `https://badereddinehaitham.github.io/trc_rth/` se mettra à jour en ~1 à 2 minutes.

---

## 8. POINTS D'ATTENTION TECHNIQUES IMPORTANTS

> [!IMPORTANT]
> **Impression PDF sous iOS Safari** :  
> Sur les appareils Apple (iPhone / iPad), le navigateur Safari bloque souvent les popups `window.print()`. Dans `lib/services/pdf_service.dart`, nous avons configuré l'utilisation prioritaire de `Printing.sharePdf(...)` avec un fallback `Blob URL / document.createElement('a')` pour garantir que le fichier PDF s'ouvre ou se télécharge sans erreur.

> [!NOTE]
> **Code Parc 'HSE'** :  
> Le code initial du parc (`TRC-RTH-PARK-001`) a été officiellement raccourci en `HSE` sur demande du service. Le scan QR et la saisie manuelle acceptent désormais `HSE`.

> [!WARNING]
> **Quotas Supabase (Plan Gratuit)** :  
> - Consommation mensuelle actuelle : ~53 Mo d'egress (soit ~1% des 5 Go offerts par Supabase chaque mois). C'est largement suffisant.
> - **Mise en pause automatique** : Sur le plan gratuit, si aucune requête n'est effectuée pendant plusieurs jours d'affilée, Supabase peut mettre le projet en veille ("Paused"). Si cela arrive, il suffit de se connecter au dashboard Supabase et de cliquer sur le bouton vert **"Restore project"** pour le réactiver en 30 secondes.

---

## 9. HISTORIQUE & ASSISTANCE INTELLIGENCE ARTIFICIELLE

Si vous devez faire évoluer le projet ou résoudre un bug avec l'aide d'un assistant IA (Antigravity, Cursor, Windsurf, Claude ou ChatGPT) :
- Donnez-lui simplement ce fichier `HANDOVER.md`. Il contient l'ensemble du contexte, des schémas et des commandes nécessaires.
- Les logs complets des sessions précédentes sont sauvegardés localement sur ce PC sous :  
  `C:\Users\Pc\.gemini\antigravity\brain\f4c75236-7c0d-420b-9764-46bb732d2128\.system_generated\logs\transcript_full.jsonl`
