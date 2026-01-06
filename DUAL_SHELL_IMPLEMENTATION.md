# Dual Shell Implementation - Summary

## Overview
This document describes the implementation of a dual-shell navigation system for the HACCP Flutter app with RBAC (Role-Based Access Control).

## Architecture

### 1. User Roles
- **Employee**: Can access normal shell, clock in/out, perform HACCP operations
- **Manager**: Same as employee (future: can manage employees)
- **Admin**: Can access admin shell with HR management, clock history, and correlation

### 2. Navigation Shells

#### Normal Shell (`/app/*`)
- **Bottom Navigation**: Home, Pointage, Températures, Réceptions, Nettoyage, Historique
- **Access**: All authenticated users (employee, manager, admin)
- **Purpose**: Daily HACCP operations and clock-in/out

#### Admin Shell (`/admin/*`)
- **Bottom Navigation**: Dashboard, RH, Pointage, Corrélation
- **Access**: Admin only
- **Purpose**: HR management, clock history, and correlation analysis
- **Feature**: "Switch to normal view" button for admins who need to clock in

### 3. Database Schema

New tables added (see `07_clock_and_hr_schema.sql`):
- `clock_sessions`: Clock-in/out sessions
- `personnel`: HR registry (separate from employees table)
- `haccp_actions`: HACCP action tracking
- `user_accounts`: Extended user info with role

### 4. Models Created

- `UserRole` enum: employee, manager, admin
- `ClockSession`: Clock-in/out session model
- `Personnel`: HR registry model with contract types
- `HaccpAction`: Generic HACCP action model

### 5. Repositories

- `ClockRepository`: Clock-in/out operations
- `PersonnelRepository`: HR CRUD operations (admin only)
- `HaccpRepository`: HACCP action tracking

### 6. Services

- `AuthService`: Enhanced with role resolution
  - Resolves role from Employee.isAdmin, Employee.role, or user_accounts table
  - Caches role for performance

### 7. Pages Created

#### Normal Shell Pages
- `PointagePage`: Clock-in/out interface
  - Shows current session status
  - Prevents double clock-in
  - Prevents clock-out without clock-in

#### Admin Shell Pages
- `AdminDashboardPage`: Admin home with quick actions
- `PersonnelRegistryPage`: CRUD for personnel registry
  - Search and filter (active/inactive)
  - Contract types: CDI, CDD, Alternance, Intérim, Extra, Stagiaire, Autre
  - Foreign worker support with permit validation
- `PersonnelFormPage`: Create/edit personnel
- `AdminClockHistoryPage`: View clock sessions with filters
  - Filter by employee, date range, open sessions
- `CorrelationPage`: Correlate clock sessions with HACCP actions
  - Shows actions during sessions vs. outside sessions (anomalies)
  - Grouped by session with action details

### 8. Routing

Router updated with:
- RBAC guards: Checks role before allowing access to routes
- Role-based redirects: Admin → `/admin/home`, Others → `/app/home`
- Shell routes: Wraps routes in appropriate shell widgets
- Legacy route support: Old routes redirect to new structure

## Usage

### For Employees/Managers
1. Login → Redirected to `/app/home`
2. Use bottom navigation to access:
   - **Pointage**: Clock in/out
   - **Températures, Réceptions, Nettoyage**: HACCP operations
   - **Historique**: View history

### For Admins
1. Login → Redirected to `/admin/home`
2. Use bottom navigation to access:
   - **RH**: Manage personnel registry
   - **Pointage**: View clock history
   - **Corrélation**: Analyze clock sessions vs. HACCP actions
3. Use "Vue normale" button to switch to normal shell if needed

## Database Setup

Execute the following SQL files in order:
1. `00_schema.sql` (existing)
2. `06_add_employee_admin_fields.sql` (existing)
3. `07_clock_and_hr_schema.sql` (new)

## Integration Notes

### HACCP Action Tracking
To track HACCP actions automatically, you should call `HaccpRepository.create()` when:
- Temperature is recorded
- Reception is performed
- Cleaning task is completed
- Corrective action is taken
- Document is uploaded
- Oil change is performed

Example:
```dart
final haccpRepo = HaccpRepository();
await haccpRepo.create(
  userId: currentUserId,
  type: HaccpActionType.temperature,
  occurredAt: DateTime.now(),
  payloadJson: {'temperature_id': tempId, 'value': tempValue},
);
```

### Role Resolution
The `AuthService.getCurrentUserRole()` method resolves roles in this priority:
1. Employee.isAdmin → admin
2. Employee.role → manager/employee
3. user_accounts.role → fallback
4. Default → employee

## Testing

### Unit Tests Recommended
- Clock In/Out rules (prevent double clock-in, prevent clock-out without clock-in)
- Route guard admin (deny non-admin access to `/admin/*`)
- Role resolution logic

## Future Enhancements

1. **HACCP Action Auto-tracking**: Integrate automatic tracking into existing HACCP operations
2. **Export**: Add CSV export for clock history
3. **Notifications**: Alert admins about anomalies
4. **Analytics**: Dashboard with statistics and charts
5. **Manager Role**: Add manager-specific features (employee management)

## Files Created/Modified

### New Files
- `lib/data/models/user_role.dart`
- `lib/data/models/clock_session.dart`
- `lib/data/models/personnel.dart`
- `lib/data/models/haccp_action.dart`
- `lib/data/repositories/clock_repository.dart`
- `lib/data/repositories/personnel_repository.dart`
- `lib/data/repositories/haccp_repository.dart`
- `lib/services/auth_service.dart`
- `lib/features/shells/normal_shell.dart`
- `lib/features/shells/admin_shell.dart`
- `lib/features/clock/pages/pointage_page.dart`
- `lib/features/admin/pages/admin_dashboard_page.dart`
- `lib/features/admin/pages/personnel_registry_page.dart`
- `lib/features/admin/pages/personnel_form_page.dart`
- `lib/features/admin/pages/admin_clock_history_page.dart`
- `lib/features/admin/pages/correlation_page.dart`
- `07_clock_and_hr_schema.sql`

### Modified Files
- `lib/core/router/app_router.dart`: Added RBAC guards and dual shell routes

