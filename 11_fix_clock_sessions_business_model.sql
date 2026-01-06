-- ============================================
-- FIX CLOCK_SESSIONS (employee_id already exists)
-- - ensure organization_id exists and is filled
-- - migrate old user_id -> employee_id if needed
-- - enforce 1 open session per employee
-- ============================================
-- This migration is IDEMPOTENT (safe to re-run)
-- Business model: ONE auth account per organization, multiple employees per org
-- Clock sessions are per EMPLOYEE (employee_id), not per auth user
-- ============================================

BEGIN;

-- 1) Ensure organization_id column exists (nullable first)
ALTER TABLE public.clock_sessions
  ADD COLUMN IF NOT EXISTS organization_id uuid;

-- 2) If old column user_id exists, attempt to migrate it into employee_id
--    Only fill employee_id where it is NULL.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public'
      AND table_name='clock_sessions'
      AND column_name='user_id'
  ) THEN
    -- Case A: user_id already contains employees.id (best case)
    UPDATE public.clock_sessions cs
    SET employee_id = cs.user_id
    WHERE cs.employee_id IS NULL;

    -- Case B: if some user_id values are auth uids, we can't map automatically without a link.
    -- We'll leave those rows with employee_id possibly wrong; we'll detect them below.
    RAISE NOTICE 'Migrated user_id into employee_id where employee_id was NULL';
  END IF;
END $$;

-- 3) Fill organization_id using employees table (only when employee_id is valid)
UPDATE public.clock_sessions cs
SET organization_id = e.organization_id
FROM public.employees e
WHERE cs.organization_id IS NULL
  AND cs.employee_id = e.id;

-- 4) Report rows that still have NULL organization_id or invalid employee_id
--    (Run this SELECT and decide what to do: delete or fix)
--    We keep it as a NOTICE-style step: you can execute it separately too.
-- SELECT cs.*
-- FROM public.clock_sessions cs
-- LEFT JOIN public.employees e ON e.id = cs.employee_id
-- WHERE cs.organization_id IS NULL OR e.id IS NULL;

-- 5) Add FK constraints if missing
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='clock_sessions_employee_id_fkey') THEN
    ALTER TABLE public.clock_sessions
      ADD CONSTRAINT clock_sessions_employee_id_fkey
      FOREIGN KEY (employee_id) REFERENCES public.employees(id)
      ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='clock_sessions_organization_id_fkey') THEN
    ALTER TABLE public.clock_sessions
      ADD CONSTRAINT clock_sessions_organization_id_fkey
      FOREIGN KEY (organization_id) REFERENCES public.organizations(id)
      ON DELETE CASCADE;
  END IF;
END $$;

-- 6) Create required indexes (safe)
CREATE INDEX IF NOT EXISTS idx_clock_sessions_employee_id
  ON public.clock_sessions(employee_id);

CREATE INDEX IF NOT EXISTS idx_clock_sessions_organization_id
  ON public.clock_sessions(organization_id);

CREATE INDEX IF NOT EXISTS idx_clock_sessions_start_at
  ON public.clock_sessions(start_at);

CREATE INDEX IF NOT EXISTS idx_clock_sessions_org_employee
  ON public.clock_sessions(organization_id, employee_id);

-- 7) CRITICAL: one open session per employee
--    This enforces: ONE employee can have ONLY ONE open session at a time
--    Multiple employees can have open sessions simultaneously
DROP INDEX IF EXISTS idx_clock_sessions_employee_open_unique;
CREATE UNIQUE INDEX idx_clock_sessions_employee_open_unique
  ON public.clock_sessions(employee_id)
  WHERE end_at IS NULL;

-- 8) Optional: if user_id exists and you no longer need it, drop it (ONLY if you're ready)
--    Uncomment this line ONLY after verifying all data is migrated and working correctly
-- ALTER TABLE public.clock_sessions DROP COLUMN IF EXISTS user_id;

COMMIT;

-- ============================================
-- VERIFICATION QUERIES (run separately)
-- ============================================

-- Check for rows with NULL organization_id (should be 0 after migration)
-- SELECT COUNT(*) as null_org_count
-- FROM public.clock_sessions
-- WHERE organization_id IS NULL;

-- Check for rows with invalid employee_id (should be 0)
-- SELECT cs.*
-- FROM public.clock_sessions cs
-- LEFT JOIN public.employees e ON e.id = cs.employee_id
-- WHERE e.id IS NULL;

-- Check for multiple open sessions per employee (should be 0 due to unique index)
-- SELECT employee_id, COUNT(*) as open_sessions
-- FROM public.clock_sessions
-- WHERE end_at IS NULL
-- GROUP BY employee_id
-- HAVING COUNT(*) > 1;

-- ============================================
-- NOTES
-- ============================================
-- After running this migration:
-- 1. Verify no NULL organization_id rows exist
-- 2. Verify no invalid employee_id rows exist
-- 3. Verify unique constraint prevents multiple open sessions per employee
-- 4. Test: multiple employees can clock in simultaneously
-- 5. Test: one employee cannot have multiple open sessions
-- 6. Only then, optionally drop user_id column if it exists
