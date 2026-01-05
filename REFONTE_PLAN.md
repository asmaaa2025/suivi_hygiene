# Refonte Plan - BekkApp / Suivi Hygiène

## Plan of Attack

### Phase 1: Compilation Fix & Foundation
1. ✅ Verify all shared widgets exist (SectionCard, EmptyState, ErrorState, HaccpBadge)
2. ✅ Verify AppTheme has all required colors
3. Create missing LoadingSkeleton widget if referenced
4. Verify all repositories exist and are compatible
5. Ensure all routes compile

### Phase 2: Database Schema (Supabase)
1. Add organizations/tenants table (multi-tenant support)
2. Add employees table (linked to organization)
3. Add suppliers table
4. Add supplier_products junction table (products ↔ suppliers)
5. Enhance receptions table (fixed time 10:00, non-conformity link)
6. Add non_conformities table (4 refusal criteria + photos)
7. Enhance cleaning_tasks (employee assignment, enabled flag)
8. Add cleaning_task_runs (completion records with employee tracking)
9. Add audit_log table (central history with actor tracking)
10. Add RLS policies for all tables

### Phase 3: Core Features Implementation
1. **Suppliers Module**
   - Suppliers list page
   - Supplier form (create/edit)
   - Link products to suppliers
   - Occasional supplier quick-add in reception flow

2. **Enhanced Reception Flow**
   - Fixed time 10:00 (non-editable)
   - Photo capture for label
   - Temperature input
   - Non-conformity check (4 criteria)
   - Non-conformity declaration form

3. **Non-Conformities Module**
   - 4 refusal criteria checkboxes
   - Photo upload for evidence
   - Declaration form
   - Link to reception

4. **Enhanced Cleaning Module**
   - Employee assignment to tasks
   - Enable/disable tasks
   - Notification scheduling (future: local notifications)
   - Task completion with employee selection
   - History with employee tracking

5. **Oil Changes**
   - Already exists, enhance with employee tracking

6. **Central History**
   - Unified audit log view
   - Filter by operation type
   - Show actor (admin/employee) + timestamp
   - Link to detail pages

### Phase 4: Multi-User System
1. Employee management (admin only)
2. Role-based access control
3. Task assignment UI
4. Actor selection in action forms (admin can select employee)
5. Traceability in all operations

### Phase 5: UI Redesign
1. **New Actions Dashboard** (landing page)
   - Quick action cards
   - FAB with bottom sheet for actions
   - Clear icons and labels
   
2. **Navigation Restructure**
   - Bottom navigation: Actions / History / Settings
   - Move history screens to History tab
   - Keep existing routes for compatibility

### Phase 6: Testing & Validation
1. Compilation check
2. Feature testing checklist
3. Edge cases handling



