# HACCP Documents Compliance Implementation

## Overview

The Documents page has been upgraded into a full HACCP "Documents" cube with compliance schedules and alerts, while preserving existing upload functionality and DB/storage compatibility.

## Implementation Summary

### 1. Database Schema

**New SQL Migration Files:**
- `26_compliance_documents_schema.sql` - Creates compliance tables and updates documents table
- `27_compliance_documents_rls.sql` - Row Level Security policies
- `28_seed_compliance_requirements.sql` - Seeds default compliance requirements per organization

**New Tables:**
- `compliance_requirements` - Stores HACCP compliance requirements (MICROBIO, PEST_CONTROL, COMPLIANCE_AUDIT)
- `compliance_events` - Tracks when compliance requirements were fulfilled

**Updated Tables:**
- `documents` - Added fields: `category`, `title`, `document_date`, `notes`, `organization_id`, `employee_id`, `compliance_requirement_id`

### 2. Models

**Location:** `lib/modules/haccp/documents/models.dart`

- `DocumentCategory` enum - MICROBIO, PEST_CONTROL, COMPLIANCE_AUDIT, OTHER
- `Document` - Enhanced document model with compliance fields
- `ComplianceRequirement` - Requirement configuration
- `ComplianceEvent` - Event tracking
- `ComplianceStatus` enum - OK, DUE_SOON, OVERDUE
- `ComplianceStatusInfo` - Status with dates and calculations

### 3. Services & Repositories

**ComplianceService** (`lib/modules/haccp/compliance/compliance_service.dart`)
- `getLastEventDate()` - Gets most recent compliance event
- `computeDueDate()` - Calculates next due date
- `calculateStatus()` - Determines compliance status (OK/DUE_SOON/OVERDUE)
- `buildDailyCheckEvents()` - Generates events for alert engine

**ComplianceRepository** (`lib/modules/haccp/compliance/compliance_repository.dart`)
- CRUD operations for requirements and events
- Organization-scoped queries

**DocumentsRepository** (Updated)
- Enhanced `createDocument()` with compliance fields
- Automatic compliance event creation for compliance categories
- Triggers compliance alert checks after upload

**ComplianceAlertIntegration** (`lib/modules/haccp/compliance/compliance_alert_integration.dart`)
- `runDailyComplianceChecks()` - Runs on app start and daily
- `checkComplianceAfterUpload()` - Runs after document upload

### 4. UI Screens

**DocumentsHomeScreen** (`lib/modules/haccp/documents/pages/documents_home_screen.dart`)
- Compliance status panel with 3 cards (MICROBIO, PEST_CONTROL, COMPLIANCE_AUDIT)
- Each card shows: last_date, next_due_date, status badge, CTA buttons
- Document list with filters (category, date range, search)
- Sort by document_date desc

**DocumentUploadScreen** (`lib/modules/haccp/documents/pages/document_upload_screen.dart`)
- Enhanced upload form with:
  - Category selection (enum)
  - Title field
  - Document date (required for compliance categories)
  - Notes (optional)
- Preselected category support from compliance cards

**DocumentDetailScreen** (`lib/modules/haccp/documents/pages/document_detail_screen.dart`)
- View document metadata
- Open/download document
- Shows compliance requirement link if applicable

**ComplianceStatusPanel** (`lib/modules/haccp/documents/widgets/compliance_status_panel.dart`)
- Reusable widget for compliance cards
- Status badges with colors
- "Ajouter un document" and "Contactez-nous" buttons

### 5. Alert Integration

**Updated `alert_rules.json`:**
- Added "documents" module
- New alert types:
  - `DOCS.COMPLIANCE_DUE_SOON` (WARN) - 14 days before due
  - `DOCS.COMPLIANCE_OVERDUE` (CRITICAL, blocking) - Past due date + grace period
- Corrective action support with:
  - Required inputs: scheduled_date, contacted_beka, reason, note
  - "Contactez-nous" link to https://bekaformation.com/contact/
- New event type: `compliance.daily_check`
- Rules for evaluating compliance status

**Alert Engine Integration:**
- Daily checks run on app start (via `main.dart`)
- Checks run after document upload in compliance categories
- Events generated via `ComplianceService.buildDailyCheckEvents()`

### 6. Routing

**Updated `app_router.dart`:**
- `/app/documents` - DocumentsHomeScreen
- `/app/documents/upload` - DocumentUploadScreen (with optional category preselection)
- `/app/documents/:id` - DocumentDetailScreen
- Same routes under `/admin/*` for admin users

**Updated HACCP Hub:**
- Added "Documents" tile (9th tile)
- Routes to `/app/documents` or `/admin/documents`

### 7. Tests

**Unit Tests** (`test/compliance_service_test.dart`)
- Tests for `getLastEventDate()`
- Tests for `computeDueDate()`
- Tests for `calculateStatus()` (OK, DUE_SOON, OVERDUE scenarios)
- Tests for `buildDailyCheckEvents()`
- Tests for inactive requirement filtering

## Default Compliance Requirements

Each organization automatically gets 3 default requirements:
- **MICROBIO** - Contrôles Microbiologiques (180 days frequency, 15 days grace)
- **PEST_CONTROL** - Dératisation / Anti-nuisibles (180 days frequency, 15 days grace)
- **COMPLIANCE_AUDIT** - Audits de Conformité (180 days frequency, 15 days grace)

Seeded via `28_seed_compliance_requirements.sql` with auto-seed trigger for new organizations.

## Status Calculation Logic

- **OK**: Today < (due_date - 14 days)
- **DUE_SOON**: Today in [due_date - 14 days, due_date]
- **OVERDUE**: Today > (due_date + grace_days)

## Permissions

- **Read**: All organization users can read documents
- **Upload**: Admin/trainer can upload (trainer role can be added via employee.is_admin flag)
- **Delete**: Only admin can delete (soft delete preferred, not yet implemented)

## Migration Instructions

1. Execute SQL files in order:
   ```sql
   26_compliance_documents_schema.sql
   27_compliance_documents_rls.sql
   28_seed_compliance_requirements.sql
   ```

2. Run Flutter app - compliance checks will run automatically on app start

3. Test document upload with compliance categories to verify event creation

## Future Enhancements

- Soft delete for documents
- Trainer role flag in employees table
- Daily scheduled task for compliance checks (via background service)
- Enhanced corrective action modal UI
- Document versioning
- Bulk document operations










