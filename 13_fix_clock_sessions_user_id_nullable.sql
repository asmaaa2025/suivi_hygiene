-- ============================================
-- FIX CLOCK_SESSIONS: Make user_id nullable or remove it
-- ============================================
-- Problem: user_id is NOT NULL but we don't use it anymore (employees are not auth users)
-- Solution: Make user_id nullable, then optionally drop it after migration
-- Business model: Use employee_id + organization_id, NOT user_id
-- ============================================
-- This migration is IDEMPOTENT (safe to re-run)
-- ============================================

BEGIN;

-- Step 1: If user_id column exists and is NOT NULL, make it nullable
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'clock_sessions'
      AND column_name = 'user_id'
  ) THEN
    -- Check if it's NOT NULL
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'clock_sessions'
        AND column_name = 'user_id'
        AND is_nullable = 'NO'
    ) THEN
      -- Make it nullable
      ALTER TABLE public.clock_sessions
        ALTER COLUMN user_id DROP NOT NULL;
      
      RAISE NOTICE 'Made user_id nullable in clock_sessions';
    ELSE
      RAISE NOTICE 'user_id is already nullable';
    END IF;
  ELSE
    RAISE NOTICE 'user_id column does not exist (already removed or never existed)';
  END IF;
END $$;

-- Step 2: Ensure employee_id exists and is NOT NULL
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'clock_sessions'
      AND column_name = 'employee_id'
  ) THEN
    -- Create employee_id column if it doesn't exist
    ALTER TABLE public.clock_sessions
      ADD COLUMN employee_id uuid;
    
    RAISE NOTICE 'Created employee_id column';
  END IF;
  
  -- Ensure employee_id is NOT NULL (after migration)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'clock_sessions'
      AND column_name = 'employee_id'
      AND is_nullable = 'YES'
  ) THEN
    -- Check if all rows have employee_id before making it NOT NULL
    IF NOT EXISTS (
      SELECT 1 FROM public.clock_sessions
      WHERE employee_id IS NULL
    ) THEN
      ALTER TABLE public.clock_sessions
        ALTER COLUMN employee_id SET NOT NULL;
      
      RAISE NOTICE 'Made employee_id NOT NULL';
    ELSE
      RAISE NOTICE 'WARNING: Some rows have NULL employee_id. Fix them before making it NOT NULL.';
    END IF;
  END IF;
END $$;

-- Step 3: Ensure organization_id exists
ALTER TABLE public.clock_sessions
  ADD COLUMN IF NOT EXISTS organization_id uuid;

-- Step 4: Fill organization_id from employees table (if not already filled)
UPDATE public.clock_sessions cs
SET organization_id = e.organization_id
FROM public.employees e
WHERE cs.organization_id IS NULL
  AND cs.employee_id = e.id;

-- Step 5: Add FK constraints if missing
DO $$
BEGIN
  -- Drop old user_id FK if it exists
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'clock_sessions_user_id_fkey') THEN
    ALTER TABLE public.clock_sessions
      DROP CONSTRAINT clock_sessions_user_id_fkey;
    RAISE NOTICE 'Dropped old user_id foreign key constraint';
  END IF;
  
  -- Add employee_id FK if missing
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'clock_sessions_employee_id_fkey') THEN
    ALTER TABLE public.clock_sessions
      ADD CONSTRAINT clock_sessions_employee_id_fkey
      FOREIGN KEY (employee_id) REFERENCES public.employees(id)
      ON DELETE CASCADE;
    RAISE NOTICE 'Added employee_id foreign key constraint';
  END IF;
  
  -- Add organization_id FK if missing
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'clock_sessions_organization_id_fkey') THEN
    ALTER TABLE public.clock_sessions
      ADD CONSTRAINT clock_sessions_organization_id_fkey
      FOREIGN KEY (organization_id) REFERENCES public.organizations(id)
      ON DELETE CASCADE;
    RAISE NOTICE 'Added organization_id foreign key constraint';
  END IF;
END $$;

-- Step 6: Create indexes
CREATE INDEX IF NOT EXISTS idx_clock_sessions_employee_id
  ON public.clock_sessions(employee_id);

CREATE INDEX IF NOT EXISTS idx_clock_sessions_organization_id
  ON public.clock_sessions(organization_id);

CREATE INDEX IF NOT EXISTS idx_clock_sessions_start_at
  ON public.clock_sessions(start_at);

CREATE INDEX IF NOT EXISTS idx_clock_sessions_org_employee
  ON public.clock_sessions(organization_id, employee_id);

-- Step 7: CRITICAL - One open session per employee
DROP INDEX IF EXISTS idx_clock_sessions_employee_open_unique;
CREATE UNIQUE INDEX idx_clock_sessions_employee_open_unique
  ON public.clock_sessions(employee_id)
  WHERE end_at IS NULL;

COMMIT;

-- ============================================
-- OPTIONAL: Drop user_id column (uncomment after verification)
-- ============================================
-- Only uncomment this AFTER verifying:
-- 1. All clock sessions have employee_id populated
-- 2. All clock sessions have organization_id populated
-- 3. The app is working correctly with employee_id
-- 4. No code references user_id anymore
--
-- BEGIN;
-- ALTER TABLE public.clock_sessions DROP COLUMN IF EXISTS user_id;
-- COMMIT;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================
-- Run these to verify the migration:
--
-- -- Check for NULL employee_id (should be 0)
-- SELECT COUNT(*) FROM public.clock_sessions WHERE employee_id IS NULL;
--
-- -- Check for NULL organization_id (should be 0 after migration)
-- SELECT COUNT(*) FROM public.clock_sessions WHERE organization_id IS NULL;
--
-- -- Check for invalid employee_id (should be 0)
-- SELECT cs.* FROM public.clock_sessions cs
-- LEFT JOIN public.employees e ON e.id = cs.employee_id
-- WHERE e.id IS NULL;
--
-- -- Check for multiple open sessions per employee (should be 0)
-- SELECT employee_id, COUNT(*) as open_sessions
-- FROM public.clock_sessions
-- WHERE end_at IS NULL
-- GROUP BY employee_id
-- HAVING COUNT(*) > 1;

