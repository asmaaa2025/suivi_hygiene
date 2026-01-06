# Business Model Refactor - Clock Sessions

## Critical Business Model Requirements

- **ONE Supabase Auth account per organization (company)**
- **Multiple employees per organization**
- **Multiple tablets can use same account simultaneously**
- **Employees are NOT Supabase Auth users**
- **Only admin has a PIN (not individual auth)**
- **Clock sessions are per EMPLOYEE, not per auth user**

## Database Schema Changes

### Migration Script: `11_fix_clock_sessions_business_model.sql`

**Changes:**
1. Add `organization_id` column to `clock_sessions`
2. Rename `user_id` to `employee_id` for clarity
3. Add unique constraint: `CREATE UNIQUE INDEX idx_clock_sessions_employee_open_unique ON clock_sessions(employee_id) WHERE end_at IS NULL;`
4. Add foreign key: `employee_id` → `employees.id` (NOT `auth.users.id`)
5. Add foreign key: `organization_id` → `organizations.id`

**Critical Constraint:**
```sql
CREATE UNIQUE INDEX idx_clock_sessions_employee_open_unique 
  ON clock_sessions(employee_id) 
  WHERE end_at IS NULL;
```
This ensures:
- One employee can have ONLY ONE open session at a time
- Multiple employees can have open sessions simultaneously
- Enforced at database level (not just application level)

## Code Changes

### 1. ClockSession Model (`lib/data/models/clock_session.dart`)
- ✅ Renamed `userId` → `employeeId`
- ✅ Added `organizationId` field
- ✅ Updated comments to clarify: `employee_id` references `employees.id`, NOT `auth.users.id`
- ✅ `fromJson` supports both old (`user_id`) and new (`employee_id`) for migration

### 2. ClockRepository (`lib/data/repositories/clock_repository.dart`)
- ✅ `getOpenSession(employeeId)` - uses `employee_id` column
- ✅ `clockIn(employeeId)` - uses `employee_id` and `organization_id`
- ✅ `clockOut(employeeId)` - uses `employee_id`
- ✅ `getHistory(employeeId, organizationId)` - supports filtering by both
- ✅ `getHistoryForEmployees(employeeIds, organizationId)` - renamed from `getHistoryForUsers`
- ✅ All methods verify employee exists in `employees` table before operations
- ✅ Supports both old (`user_id`) and new (`employee_id`) column names during migration

### 3. PointagePage (`lib/features/clock/pages/pointage_page.dart`)
- ✅ Uses `employeeId` from selected employee (not auth user ID)
- ✅ Validates employee exists before clock-in
- ✅ Loads sessions from DB (persisted, survives app restarts)

### 4. Admin Pages
- ✅ `AdminClockHistoryPage` - uses `getHistoryForEmployees` instead of `getHistoryForUsers`
- ✅ `CorrelationPage` - uses `getHistoryForEmployees` instead of `getHistoryForUsers`
- ✅ Both pages use `session.employeeId` instead of `session.userId`

## Migration Steps

1. **Execute SQL migration on Supabase:**
   ```sql
   -- Run: 11_fix_clock_sessions_business_model.sql
   ```

2. **Verify migration:**
   - Check that `clock_sessions` has `employee_id` column (not `user_id`)
   - Check that `clock_sessions` has `organization_id` column
   - Check that unique constraint exists: `idx_clock_sessions_employee_open_unique`
   - Check foreign keys: `employee_id` → `employees.id`, `organization_id` → `organizations.id`

3. **Test:**
   - Multiple employees can clock in simultaneously
   - One employee cannot have multiple open sessions
   - Clock sessions persist across app restarts
   - Clock sessions are per employee, not per auth user

## What Must NOT Be Done

❌ **DO NOT** use `auth.users.id` to represent employees
❌ **DO NOT** share a single clock session across employees
❌ **DO NOT** store "current clock session" globally without `employee_id`
❌ **DO NOT** reset sessions on app restart
❌ **DO NOT** link clock sessions to `auth.users` - only to `employees`

## Verification Checklist

- [ ] SQL migration executed successfully
- [ ] `clock_sessions.employee_id` exists and references `employees.id`
- [ ] `clock_sessions.organization_id` exists and references `organizations.id`
- [ ] Unique constraint `idx_clock_sessions_employee_open_unique` exists
- [ ] Multiple employees can clock in simultaneously
- [ ] One employee cannot have multiple open sessions
- [ ] Clock sessions persist across app restarts
- [ ] Clock sessions are loaded from DB, not in-memory state

## Notes

- The code supports both old (`user_id`) and new (`employee_id`) column names during migration
- After migration, all clock operations use `employee_id` from `employees` table
- `Personnel` table is separate from `Employee` table - clock sessions use `Employee`, not `Personnel`
- Admin pages may need further refactoring to use `Employee` repository instead of `Personnel` repository for clock sessions

