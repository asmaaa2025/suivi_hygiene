-- ============================================
-- FIX CLOCK_SESSIONS CONSTRAINT - FINAL VERSION
-- ============================================
-- This script fixes the foreign key constraint to reference employees instead of users
-- Execute this in Supabase SQL Editor
-- ============================================

-- Step 1: Find and drop ALL foreign key constraints on clock_sessions.user_id
-- (There might be multiple constraints with different names)

DO $$
DECLARE
    r RECORD;
    user_id_attnum INTEGER;
BEGIN
    -- Get the attribute number for user_id column
    SELECT attnum INTO user_id_attnum
    FROM pg_attribute
    WHERE attrelid = 'public.clock_sessions'::regclass
    AND attname = 'user_id';
    
    -- Find all foreign key constraints on clock_sessions.user_id
    FOR r IN (
        SELECT conname, conrelid::regclass AS table_name
        FROM pg_constraint
        WHERE conrelid = 'public.clock_sessions'::regclass
        AND contype = 'f'
        AND conkey::integer[] = ARRAY[user_id_attnum]::integer[]
    ) LOOP
        EXECUTE 'ALTER TABLE public.clock_sessions DROP CONSTRAINT IF EXISTS ' || quote_ident(r.conname);
        RAISE NOTICE 'Dropped constraint: %', r.conname;
    END LOOP;
END $$;

-- Step 2: Verify the constraint is dropped
-- (This will show any remaining constraints)

-- Step 3: Add the new foreign key constraint to employees table
ALTER TABLE public.clock_sessions
  ADD CONSTRAINT clock_sessions_employee_id_fkey 
  FOREIGN KEY (user_id) REFERENCES public.employees(id) ON DELETE CASCADE;

-- Step 4: Verify the new constraint
SELECT 
    conname AS constraint_name,
    conrelid::regclass AS table_name,
    confrelid::regclass AS referenced_table,
    a.attname AS column_name,
    af.attname AS referenced_column
FROM pg_constraint c
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
JOIN pg_attribute af ON af.attrelid = c.confrelid AND af.attnum = ANY(c.confkey)
WHERE conrelid = 'public.clock_sessions'::regclass
AND conname = 'clock_sessions_employee_id_fkey';

-- If the query above returns a row, the constraint is correctly set up!

