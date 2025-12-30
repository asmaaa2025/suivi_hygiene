# Éléments Supprimés lors de la Refonte

Ce document liste tous les éléments qui ont été supprimés, remplacés ou dépréciés lors de la refonte de l'application de suivi d'hygiène.

## 🔐 Flux d'Authentification (Login → Dashboard)

### Nouveau Flux d'Authentification
1. **Page de Login** (`lib/screens/login_page.dart` ou `lib/features/auth/pages/login_page.dart`)
   - Première page affichée à l'utilisateur
   - Authentification via Supabase Auth (`signInWithPassword`)
   - Validation des identifiants email/mot de passe
   - Affichage du message "Connexion réussie ! Redirection..." après succès

2. **Redirection Automatique**
   - Après connexion réussie, redirection automatique vers `/home`
   - Utilisation de `context.go('/home')` dans GoRouter
   - Le router vérifie automatiquement l'état d'authentification et redirige si nécessaire

3. **Dashboard/Home** (`lib/features/dashboard/pages/dashboard_page.dart`)
   - Page d'accueil affichée après authentification
   - Route : `/home` dans `app_router.dart`
   - **Statut** : ✅ Implémenté - Dashboard complet avec navigation vers toutes les sections
   - **Fonctionnalités** :
     - Section "Saisie rapide" pour accéder rapidement aux formulaires
     - Section "Consultations" pour accéder aux listes (températures, réceptions, nettoyages, changements d'huile, produits)
     - Section "Outils" pour l'historique unifié et les étiquettes
     - Bouton paramètres dans l'AppBar

### Configuration du Router
- **Fichier** : `lib/core/router/app_router.dart`
- **Route initiale** : `/login`
- **Redirection automatique** :
  - Si non connecté → `/login`
  - Si connecté et sur `/login` → `/home`
- **Protection des routes** : Toutes les routes sont protégées par vérification de session Supabase

## 📁 Fichiers Supprimés/Remplacés

### Pages/Écrans
- **`lib/screens/rapports_page.dart`** ❌
  - **Statut** : Supprimé (backup disponible : `rapports_page.dart.backup`)
  - **Raison** : Remplacé par une nouvelle architecture de features
  - **Fonctionnalités perdues** :
    - Génération de rapports PDF
    - Export CSV
    - Statistiques rapides (températures, nettoyages, réceptions, produits)
    - Configuration de période de rapport
  - **Note** : Le fichier backup contient l'ancienne implémentation basée sur `DatabaseHelper` (SQLite local)

### Services Dépréciés
- **`lib/services/db_service.dart`** ⚠️
  - **Statut** : Déprécié (peut être supprimé)
  - **Raison** : Migration vers Supabase-first architecture
  - **Note** : Mentionné dans README comme "Legacy temperature storage (may be deprecated)"

- **`lib/services/auto_sync_service.dart`** (partiellement)
  - **Ligne supprimée** : `import '../database_helper.dart'; // Removed - Supabase-first now`
  - **Raison** : Migration vers Supabase uniquement

## 🗄️ Colonnes de Base de Données Legacy

Les colonnes suivantes sont marquées comme "Legacy" dans le schéma SQL et sont progressivement migrées :

### Table `temperatures`
- **`photo_path`** → Remplacé par `photo_url`
  - Migration automatique dans le schéma SQL
- **`created_by`** → Remplacé par `owner_id`
  - Colonne legacy conservée pour compatibilité
- **`appareil`** (TEXT) → Remplacé par `appareil_id` (UUID FK)
  - Conservé pour compatibilité avec ancien code

### Table `nettoyages`
- **`task_id`** → Remplacé par `tache_id`
  - Migration automatique dans le schéma SQL
- **`action`** (TEXT) → Legacy column
  - Conservé pour compatibilité, remplacé par système de tâches (`taches_nettoyage`)
- **`created_by`** → Remplacé par `owner_id`
  - Colonne legacy conservée

### Table `receptions`
- **`photo_path`** → Remplacé par `photo_url`
  - Migration automatique
- **`user_id`** → Remplacé par `owner_id`
  - Migration automatique
- **`created_by`** → Remplacé par `owner_id`
  - Migration automatique
- **`produit`** (TEXT) → Remplacé par `produit_id` (UUID FK)
  - Conservé pour compatibilité
- **`article`** → Colonne de compatibilité
- **`date`** → Remplacé par `received_at`
  - Migration automatique : `received_at = date` si null

### Table `friteuses`
- **`user_id`** → Remplacé par `owner_id`
  - Migration automatique

### Table `oil_changes`
- **`created_by`** → Remplacé par `owner_id`
  - Colonne legacy conservée
- **`date_changement`** → Remplacé par `changed_at`
  - Colonne legacy conservée

### Table `documents`
- **`chemin`** → Remplacé par `fichier_url`
  - Migration automatique
- **`titre`** → Remplacé par `nom`
  - Colonne legacy conservée
- **`user_id`** → Remplacé par `owner_id`
  - Migration automatique
- **`date_creation`** → Remplacé par `created_at`
  - Migration automatique

## 🏗️ Architecture Supprimée

### Système de Base de Données
- **SQLite Local (sqflite) comme stockage principal** ❌
  - **Remplacé par** : Supabase (PostgreSQL) comme stockage principal
  - **Services affectés** :
    - `DatabaseHelper` - Maintenant stub/incomplet
    - `optimized_database_helper.dart` - Conservé pour cache local uniquement
    - `plesk_sync_service.dart` - Sync service (peut être déprécié)
  - **Note** : L'app est maintenant "Supabase-first". SQLite est utilisé uniquement pour le cache local/offline.

### Système d'Authentification
- **Ancien système de login** ❌
  - **Remplacé par** : Supabase Auth
  - **Fichiers concernés** :
    - `lib/screens/login_page.dart` - Refactorisé pour utiliser Supabase
    - `lib/features/auth/pages/login_page.dart` - Nouvelle version
  - **Changements** :
    - Suppression des credentials hardcodés
    - Migration vers variables d'environnement
    - Utilisation de `signInWithPassword` de Supabase

### Système de Routage
- **Ancien système de navigation** ❌
  - **Remplacé par** : GoRouter
  - **Fichier** : `lib/core/router/app_router.dart`
  - **Changements** :
    - Routes centralisées
    - Redirection automatique basée sur l'état d'authentification
    - Suppression de `AuthGate` (ou utilisation réduite)

## 🔐 Sécurité - Éléments Supprimés

### Credentials Hardcodés
- **Supabase URL et API keys hardcodées** ❌
  - **Remplacé par** : Variables d'environnement (`.env`)
  - **Fichier de config** : `lib/core/config/supabase_config.dart`
  - **Note** : Mentionné dans CHANGELOG.md comme amélioration de sécurité

## 📱 Structure de Code Supprimée

### Organisation par Screens
- **Ancienne structure** : Tout dans `lib/screens/`
- **Nouvelle structure** : Organisation par features dans `lib/features/`
  - `lib/features/auth/`
  - `lib/features/cleaning/`
  - `lib/features/dashboard/`
  - `lib/features/entry/`
  - `lib/features/history/`
  - `lib/features/labels/`
  - `lib/features/oil/`
  - `lib/features/products/`
  - `lib/features/receptions/`
  - `lib/features/settings/`
  - `lib/features/temperatures/`

### Pages Remplacées
- **`nettoyage_page.dart`** ⚠️
  - **Note** : Contient un warning : "Old format detected. Use CleaningPage instead."
  - **Remplacé par** : `lib/features/cleaning/pages/cleaning_page.dart`

## 🔄 Migrations Automatiques

Le schéma SQL (`00_schema.sql`) contient des scripts de migration automatique pour :
1. Migration de `photo_path` → `photo_url`
2. Migration de `user_id` → `owner_id`
3. Migration de `task_id` → `tache_id`
4. Migration de `created_by` → `owner_id`
5. Migration de `date` → `received_at`
6. Migration de `chemin` → `fichier_url`
7. Migration de `date_changement` → `changed_at`

## 📝 Notes Importantes

### Compatibilité
- Les colonnes legacy sont **conservées** dans le schéma pour assurer la compatibilité avec les anciennes données
- Les migrations automatiques copient les données des anciennes colonnes vers les nouvelles
- Les anciennes colonnes ne sont **pas supprimées** pour éviter la perte de données

### Stubs et Technical Debt
Plusieurs composants sont marqués comme "stub" ou "TODO" et peuvent être considérés comme partiellement supprimés :

#### Pages UI (Stubs)
- **`lib/features/dashboard/pages/dashboard_page.dart`** ✅
  - **Statut** : ✅ **IMPLÉMENTÉ** - Dashboard complet avec navigation
  - **Fonctionnalités ajoutées** :
    - Section "Saisie rapide" avec accès direct aux formulaires
    - Section "Consultations" avec liens vers toutes les listes
    - Section "Outils" pour historique et étiquettes
    - Navigation intégrée avec GoRouter
    - Design cohérent avec le reste de l'application
  - **Route** : `/home` (utilisé après connexion)

- **`lib/features/cleaning/pages/cleaning_todo_page.dart`** ⚠️
  - **Statut** : Stub - Affiche seulement un placeholder
  - **Manque** : Liste des tâches, statut de complétion, détails des tâches
  - **TODO** : Récupérer les tâches depuis `TacheNettoyageRepository.getTasksDueForDate()`

- **`lib/features/cleaning/pages/cleaning_history_page.dart`** ⚠️
  - **Statut** : Stub - Affiche seulement un placeholder
  - **Manque** : Historique des nettoyages, filtrage par date, recherche
  - **TODO** : Récupérer les tâches complétées depuis Supabase (table `nettoyages`)

- **`lib/features/temperatures/pages/temperature_form_page.dart`** ⚠️
  - **Statut** : Stub - Formulaire non implémenté
  - **Manque** : Champs (appareil, température, remarque), date picker, upload photo
  - **TODO** : Soumettre à `TemperatureRepository` ou `ApiService.createTemperature()`

- **`lib/features/receptions/pages/reception_form_page.dart`** ⚠️
  - **Statut** : Stub - Formulaire non implémenté
  - **Manque** : Champs (fournisseur, produit, quantité, statut, remarque), date picker, upload documents
  - **TODO** : Soumettre à `ReceptionsRepository` ou `ApiService.createReception()`

- **`lib/features/oil/pages/oil_change_form_page.dart`** ⚠️
  - **Statut** : Stub - Formulaire non implémenté
  - **Manque** : Champs (friteuse, quantité, type_huile, responsable, remarque), date picker, upload photo
  - **TODO** : Soumettre à `OilChangeRepository.createOilChange()`

- **`lib/features/history/pages/history_page.dart`** ⚠️
  - **Statut** : Stub - Page d'historique unifié non implémentée
  - **Manque** : Requête unifiée pour températures, réceptions, nettoyages, changements d'huile
  - **TODO** : Implémenter le feed unifié

#### Services/Repositories (Stubs)
- **`lib/data/local/database_helper.dart`** ⚠️
  - **Statut** : Stub incomplet - Schéma de base de données non implémenté
  - **Manque** : Définitions de tables complètes (releves, appareils, receptions, etc.)
  - **Manque** : Logique de migration dans `onUpgrade`
  - **Manque** : Gestion d'erreurs, support de transactions
  - **Note** : Peut ne plus être nécessaire si l'app est Supabase-only
  - **TODO** : Implémenter le schéma complet ou supprimer si Supabase-only

- **`lib/data/repositories/oil_repository.dart`** ⚠️
  - **Statut** : Partiellement implémenté
  - **Manque** : Gestion d'erreurs avec AppExceptions
  - **Manque** : Filtrage RLS par `owner_id`
  - **Manque** : Support de cache, pagination
  - **Manque** : Méthodes update/delete pour friteuses
  - **Manque** : Validation des données de changement d'huile

#### Thème (Placeholder)
- **`lib/core/theme/app_theme.dart`** ⚠️
  - **Statut** : Placeholder - Getters de couleurs non définis
  - **Manque** : Schéma de couleurs Material 3
  - **Manque** : Couleurs de statut HACCP (critical, warning, ok, info)
  - **Manque** : Couleurs de texte (primary, secondary, tertiary)
  - **Manque** : Couleurs de fond appropriées
  - **TODO** : Définir le schéma de couleurs complet

#### Autres TODOs
- **`lib/services/auto_sync_service.dart`** : `'responsable': 'User'` - TODO: Récupérer depuis auth
- **`lib/screens/parametres_page.dart`** : TODO: Implémenter la synchronisation Supabase
- **`lib/screens/documents_page.dart`** : TODO: Ouvrir URL/télécharger fichier, implémenter le partage
- **`lib/screens/suivi_huile_page.dart`** : TODO: Implémenter suppression depuis DB

### Fichiers de Backup
- `lib/screens/rapports_page.dart.backup` - Contient l'ancienne implémentation de la page de rapports

## 🎯 Résumé des Changements Majeurs

1. **Migration SQLite → Supabase** : Stockage principal déplacé vers le cloud
2. **Migration colonnes legacy** : Standardisation des noms de colonnes (`owner_id`, `photo_url`, etc.)
3. **Refonte authentification** : Supabase Auth au lieu d'un système custom
4. **Réorganisation code** : Structure par features au lieu de screens
5. **Suppression credentials hardcodés** : Variables d'environnement
6. **Suppression page rapports** : Fonctionnalité non réimplémentée dans la nouvelle architecture

---

**Date de création** : 2024-12-29  
**Dernière mise à jour** : 2024-12-29

