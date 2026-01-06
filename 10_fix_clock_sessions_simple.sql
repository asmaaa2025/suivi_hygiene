-- ============================================
-- FIX CLOCK_SESSIONS CONSTRAINT - SIMPLE VERSION
-- ============================================
-- This script fixes the foreign key constraint to reference employees instead of users
-- Execute this in Supabase SQL Editor
-- ============================================

-- Step 1: Drop the existing constraint (try all possible names)
ALTER TABLE public.clock_sessions 
  DROP CONSTRAINT IF EXISTS clock_sessions_user_id_fkey;

ALTER TABLE public.clock_sessions 
  DROP CONSTRAINT IF EXISTS clock_sessions_employee_id_fkey;

-- Step 2: List all foreign key constraints on clock_sessions to see what exists
-- (This is just for information, you can comment it out)
SELECT 
    conname AS constraint_name,
    conrelid::regclass AS table_name,
    confrelid::regclass AS referenced_table
FROM pg_constraint
WHERE conrelid = 'public.clock_sessions'::regclass
AND contype = 'f';

-- Step 3: Add the new foreign key constraint to employees table
ALTER TABLE public.clock_sessions
  ADD CONSTRAINT clock_sessions_employee_id_fkey 
  FOREIGN KEY (user_id) REFERENCES public.employees(id) ON DELETE CASCADE;

-- Step 4: Verify the constraint was created correctly
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

-- Expected result: 
-- constraint_name: clock_sessions_employee_id_fkey
-- referenced_table: employees
-- referenced_column: id

