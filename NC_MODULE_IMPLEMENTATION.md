# Non-Conformity (NC) Module Implementation

## Overview
Complete implementation of the NC module with 8-section form structure, integrated with Temperature, Reception, Oil, and Cleaning alert triggers.

## Files Created

### Database Schema
- `29_non_conformities_schema.sql` - Complete schema with all tables
- `30_non_conformities_rls.sql` - Row Level Security policies

### Models
- `lib/data/models/nc_models.dart` - All NC models (NonConformity, NCCause, NCSolution, NCAction, NCVerification, NCAttachment)

### Repositories
- `lib/data/repositories/nc_repository.dart` - Complete CRUD operations
- `lib/data/repositories/nc_prefill_mappers.dart` - Prefill mapping functions for all source types

### UI Screens
- `lib/features/haccp/pages/nc_list_page.dart` - List screen with filters
- `lib/features/haccp/pages/nc_detail_page.dart` - 8-section form with ExpansionPanels

### Router
- Added routes in `lib/core/router/app_router.dart`:
  - `/app/nc` - List page
  - `/app/nc/new` - Create new NC
  - `/app/nc/:id` - Edit existing NC

### Navigation
- Added NC button in `lib/features/haccp/pages/alerts_inbox_page.dart`

## Integration Points

### Temperature Module
When a temperature reading is out of threshold:
1. Show alert dialog
2. Offer "Créer fiche NC" button
3. If clicked, navigate to NC form with prefill data using `mapTemperatureToNC()`

### Reception Module
When a reception has non-conformity:
1. Show alert dialog
2. Offer "Créer fiche NC" button
3. If clicked, navigate to NC form with prefill data using `mapReceptionToNC()`

### Oil Module
When oil change is overdue:
1. Show alert dialog
2. Offer "Créer fiche NC" button
3. If clicked, navigate to NC form with prefill data using `mapOilToNC()`

### Cleaning Module
When cleaning task is missed:
1. Show alert dialog
2. Offer "Créer fiche NC" button
3. If clicked, navigate to NC form with prefill data using `mapCleaningToNC()`

## Next Steps for Integration

To complete the integration, add NC creation triggers in:

1. **Temperature alerts** (`lib/features/temperatures/pages/temperature_form_page.dart`):
   - In `_showCorrectiveActionDialog()`, add "Créer fiche NC" button
   - Use `mapTemperatureToNC()` to prefill

2. **Reception alerts** (`lib/features/receptions/pages/reception_form_page.dart`):
   - When non-conformity is detected, offer NC creation
   - Use `mapReceptionToNC()` to prefill

3. **Oil alerts** (`lib/features/oil/pages/suivi_huile_page.dart`):
   - When oil change is overdue, offer NC creation
   - Use `mapOilToNC()` to prefill

4. **Cleaning alerts** (`lib/features/cleaning/pages/cleaning_page.dart`):
   - When task is missed, offer NC creation
   - Use `mapCleaningToNC()` to prefill

## Storage Bucket

Create Supabase Storage bucket: `nc-files` (private bucket for NC attachments)

## Database Migration Order

Execute SQL files in this order:
1. `00_schema.sql` (if not already executed)
2. `10_security.sql` (if not already executed)
3. `29_non_conformities_schema.sql`
4. `30_non_conformities_rls.sql`

## Testing Checklist

- [ ] Create NC manually from list page
- [ ] Create NC from temperature alert
- [ ] Create NC from reception alert
- [ ] Create NC from oil alert
- [ ] Create NC from cleaning alert
- [ ] Edit existing NC
- [ ] Add causes, solutions, actions, verifications
- [ ] Upload attachments
- [ ] Filter NCs by status, source, category, date
- [ ] Change NC status
- [ ] Delete NC (cascades to child records)










