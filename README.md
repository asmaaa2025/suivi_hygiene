# Suivi HACCP

Flutter mobile application for HACCP (Hazard Analysis Critical Control Points) hygiene tracking in butcher shops and food service establishments. Built with Flutter and Supabase backend.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.2.3+-02569B?logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase)](https://supabase.com)

## Features

- 🌡️ **Temperature Monitoring** - Track temperatures for fridges, freezers, and equipment
- 🧹 **Cleaning Management** - Schedule and track cleaning tasks with recurrence
- 📦 **Product Reception** - Record product receipts with temperature checks
- 🛢️ **Oil Change Tracking** - Monitor fryer oil changes
- 📋 **Product Management** - Manage products with DLC (expiry date) tracking
- 📸 **Photo Documentation** - Attach photos to records
- 🏷️ **Label Printing** - Print HACCP-compliant labels
- 📊 **Reports & Export** - Generate PDF reports and CSV exports

## Tech Stack

- **Frontend**: Flutter 3.2.3+ (Dart 3.2.3+)
- **Backend**: Supabase (PostgreSQL, Auth, Storage)
- **State Management**: Riverpod
- **Local Storage**: Hive
- **PDF Generation**: pdf package
- **Label Printing**: Blue Thermal Printer

## Prerequisites

- Flutter SDK 3.2.3 or higher
- Dart SDK 3.2.3 or higher
- Android Studio / Xcode (for mobile development)
- Supabase account and project
- Git

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/asmaaa2025/suivi_haccp.git
cd suivi_haccp
```

Or using SSH:
```bash
git clone git@github.com:asmaaa2025/suivi_haccp.git
cd suivi_haccp
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Set up environment variables

Create a `.env` file in the project root:

```bash
cp .env.example .env
```

Edit `.env` and add your Supabase credentials:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_PHOTOS_BUCKET=haccp-photos
SUPABASE_RELEVES_BUCKET=releves
```

**Where to find your Supabase credentials:**
1. Go to your [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Go to **Settings → API**
4. Copy the **Project URL** and **anon public** key

**Important**: Never commit the `.env` file. It's already in `.gitignore`.

### 4. Set up Supabase database

Execute the SQL files in order in your Supabase SQL Editor:

1. `00_schema.sql` - Creates all tables, indexes, functions, and triggers
2. `10_security.sql` - Sets up Row Level Security (RLS) policies
3. `20_storage.sql` - Creates storage buckets and policies
4. `90_seed.sql` - (Optional) Adds sample data for development

**Important**: Execute files in this exact order.

### 5. Run the application

```bash
# For development
flutter run

# For a specific device
flutter run -d <device-id>

# List available devices
flutter devices
```

## Project Structure

```
lib/
├── core/              # Core configuration and utilities
│   ├── config/        # App configuration (Supabase, etc.)
│   ├── router/        # Navigation routing
│   └── theme/         # App theme
├── data/              # Data models and repositories
├── features/          # Feature modules
│   ├── auth/          # Authentication
│   ├── cleaning/      # Cleaning management
│   ├── products/      # Product management
│   ├── receptions/    # Product reception
│   ├── temperatures/  # Temperature tracking
│   └── oil/           # Oil change tracking
├── services/          # API and business logic services
├── screens/           # Screen widgets
├── shared/            # Shared widgets and utilities
└── main.dart          # App entry point

SQL Files:
├── 00_schema.sql      # Database schema
├── 10_security.sql    # RLS policies
├── 20_storage.sql     # Storage setup
└── 90_seed.sql        # Seed data (optional)
```

## Database Schema

The application uses the following main tables:

- `appareils` - Temperature monitoring devices
- `temperatures` - Temperature readings
- `nettoyages` - Cleaning records
- `taches_nettoyage` - Recurring cleaning tasks
- `produits` - Products
- `receptions` - Product reception records
- `friteuses` - Fryers
- `oil_changes` - Oil change records
- `label_prints` - Label print history
- `documents` - Document metadata

All tables use Row Level Security (RLS) for data isolation per user.

## Development

### Code formatting

```bash
flutter format .
```

### Code analysis

```bash
flutter analyze
```

### Running tests

```bash
flutter test
```

### Building for production

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

---

## 📦 Procédure de mise à jour de l’application (OTA)

Fiche de procédure pour les mises à jour OTA de **BekkApp / Suivi Hygiène**. Chaque release doit suivre les mêmes étapes pour éviter les erreurs (404, mauvaise version, APK introuvable, etc.).

### 1️⃣ Vérifier que le repo GitHub est public

**GitHub → Repository → Settings → General**

Vérifier : **Repository visibility = Public**

Sinon les APK dans **GitHub Releases** ne seront pas téléchargeables et tu obtiendras une **Erreur 404**.

---

### 2️⃣ Mettre à jour la version dans Flutter

Dans **`pubspec.yaml`** :

```yaml
version: 1.0.4+2
```

Règle : **version utilisateur + build number** (ex. `1.0.3+1`, `1.0.4+2`, `1.0.5+3`).

---

### 3️⃣ Builder la nouvelle version APK

```bash
flutter clean
flutter pub get
flutter build apk --release
```

APK généré dans : **`build/app/outputs/flutter-apk/app-release.apk`**

---

### 4️⃣ Renommer l’APK

Renommer **`app-release.apk`** en **`bekkapp_vX.X.X.apk`** (ex. `bekkapp_v1.0.4.apk`).

---

### 5️⃣ Créer une Release GitHub

**GitHub → Repo → Releases → Create new release**

- **Tag** : `v1.0.4`
- **Titre** : `Version 1.0.4`
- **Assets** : uploader **`bekkapp_v1.0.4.apk`**

---

### 6️⃣ Copier l’URL de téléchargement

Format :

```
https://github.com/asmaaa2025/suivi_hygiene/releases/download/v1.0.4/bekkapp_v1.0.4.apk
```

Tester dans le navigateur : le téléchargement doit démarrer.

---

### 7️⃣ Mettre à jour `version.json`

Dans **Supabase → Storage → Bucket `apk`**, télécharger **`version.json`** et le modifier :

```json
{
  "version": "1.0.4",
  "build": 2,
  "apk_url": "https://github.com/asmaaa2025/suivi_hygiene/releases/download/v1.0.4/bekkapp_v1.0.4.apk",
  "mandatory": false,
  "changelog": "Corrections et améliorations de stabilité"
}
```

---

### 8️⃣ Réupload du `version.json`

Supprimer l’ancien **`version.json`** dans Supabase Storage, puis uploader le nouveau dans **Supabase → Storage → apk**.

---

### 9️⃣ Tester la mise à jour

Sur la tablette : **Paramètres → Vérifier les mises à jour**. Résultat attendu : **Nouvelle version disponible** → Téléchargement APK → Installation.

---

### 🔟 Vérifier que la mise à jour fonctionne

Après installation : **Paramètres → À propos** et vérifier la version affichée (ex. **Version 1.0.4**).

---

### 🧠 Bonnes pratiques

Conserver les anciennes APK (`bekkapp_v1.0.1.apk`, `bekkapp_v1.0.2.apk`, etc.) pour un **rollback rapide** en cas de bug.

---

### ⚠️ Erreurs courantes

| Problème | Cause |
|----------|--------|
| **404 download** | Repo GitHub privé ou mauvais nom de fichier |
| **APK non téléchargé** | `apk_url` incorrect dans `version.json` |
| **Update non détectée** | Version dans `pubspec.yaml` égale ou supérieure à celle dans `version.json` (il faut que la version serveur soit **plus élevée**) |

---

### 📊 Architecture du système de mise à jour

```
Flutter App
     │
     │ check version.json
     ▼
Supabase Storage (apk/version.json)
     │
     ▼
GitHub Release APK
     │
     ▼
Download → Install
```

Avec ce système tu peux gérer **des dizaines de tablettes clients** sans passer par le Play Store.

---

## Configuration

### Environment Variables

Required (see `.env.example`):

- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_ANON_KEY` - Your Supabase anonymous key

Optional:

- `SUPABASE_PHOTOS_BUCKET` - Storage bucket for photos (default: `haccp-photos`)
- `SUPABASE_RELEVES_BUCKET` - Storage bucket for temperature logs (default: `releves`)
- `PLESK_USERNAME` - Plesk username (if using Plesk sync service)
- `PLESK_PASSWORD` - Plesk password (if using Plesk sync service)

### Supabase Setup

1. Create a new Supabase project at [supabase.com](https://supabase.com)
2. Run the SQL migration files in order (see Installation step 4)
3. Create storage buckets:
   - `haccp-photos` (public)
   - `temperatures` (private)
   - `receptions` (private)
   - `nettoyage` (private)
   - `documents` (private)
   - `releves` (private)

## Security Notes

- **Never commit secrets**: The `.env` file is in `.gitignore` and should never be committed
- **Key rotation**: If any Supabase keys were exposed, rotate them immediately in the Supabase dashboard
- **Service role key**: Never use the service_role key in client/mobile code. It should only be used server-side
- **RLS policies**: All tables use Row Level Security for user data isolation

## Contributing

This is a private repository. For contribution guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

If you discover a security vulnerability, please see [SECURITY.md](SECURITY.md) for instructions on how to report it.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Local Database vs Sync Services

The application uses two data storage approaches:

### Supabase (Primary)
- **Primary data storage**: All production data is stored in Supabase
- **Real-time sync**: Changes are immediately synced to Supabase
- **RLS security**: Row Level Security ensures user data isolation

### Local SQLite (sqflite) - Legacy/Offline Support
- **Local caching**: Some services use `sqflite` for offline support
- **Services using local DB**:
  - `db_service.dart` - Legacy temperature storage (may be deprecated)
  - `optimized_database_helper.dart` - Local caching layer
  - `plesk_sync_service.dart` - Sync service for Plesk integration
- **Note**: The app is primarily Supabase-first. Local DB usage is being phased out in favor of Supabase-only architecture.

### Sync Services
- **`sync_service.dart`**: Handles synchronization between local and Supabase
- **`plesk_sync_service.dart`**: Syncs data with Plesk server (if configured)
- **`auto_sync_service.dart`**: Automatic background synchronization

## Stubs / Technical Debt

The following components are **stub implementations** that need to be completed:

### Pages (UI Stubs)
- **`CleaningTodoPage`** (`lib/features/cleaning/pages/cleaning_todo_page.dart`)
  - Missing: Task list display, completion status, task details
  - TODO: Fetch from `TacheNettoyageRepository.getTasksDueForDate()`
  
- **`CleaningHistoryPage`** (`lib/features/cleaning/pages/cleaning_history_page.dart`)
  - Missing: History list, date filtering, search
  - TODO: Fetch completed cleaning tasks from Supabase
  
- **`TemperatureFormPage`** (`lib/features/temperatures/pages/temperature_form_page.dart`)
  - Missing: Form fields, validation, photo upload
  - TODO: Implement full temperature entry form
  
- **`ReceptionFormPage`** (`lib/features/receptions/pages/reception_form_page.dart`)
  - Missing: Form fields, validation, document upload
  - TODO: Implement product reception form
  
- **`OilChangeFormPage`** (`lib/features/oil/pages/oil_change_form_page.dart`)
  - Missing: Form fields, validation, photo upload
  - TODO: Implement oil change entry form

### Services/Repositories (Partial Stubs)
- **`DatabaseHelper`** (`lib/data/local/database_helper.dart`)
  - Missing: Full database schema, migrations, proper error handling
  - TODO: Implement complete schema or remove if Supabase-only
  
- **`OilRepository`** (`lib/data/repositories/oil_repository.dart`)
  - Missing: Update/delete methods, proper error handling, RLS filtering
  - TODO: Complete CRUD operations, add caching support

### Theme (Placeholder)
- **`AppTheme`** (`lib/core/theme/app_theme.dart`)
  - Missing: Proper color scheme matching app design
  - TODO: Define Material 3 color scheme, status colors, text colors

**Note**: All stub files are marked with `// STUB:` comments and `// TODO:` markers indicating what needs to be implemented.

## Support

For issues and feature requests, please use the [GitHub Issues](https://github.com/asmaaa2025/suivi_haccp/issues) page.

## Repository

- **GitHub**: https://github.com/asmaaa2025/suivi_haccp
- **SSH**: git@github.com:asmaaa2025/suivi_haccp.git
