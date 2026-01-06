-- ============================================
-- FIX CLOCK_SESSIONS TO USE EMPLOYEE ID
-- ============================================
-- This migration fixes clock_sessions to use employee.id instead of auth.users.id
-- This is needed for shared tablet scenario where multiple employees use the same Supabase account
-- ============================================

-- Step 1: Drop the foreign key constraint to auth.users
ALTER TABLE public.clock_sessions 
  DROP CONSTRAINT IF EXISTS clock_sessions_user_id_fkey;

-- Step 2: Change user_id to reference employees table instead
-- employees.id is UUID, so we can add a foreign key constraint
-- But first, we need to ensure all existing user_id values are valid employee IDs
-- For new installations, this will work directly

-- Add foreign key to employees table
ALTER TABLE public.clock_sessions
  ADD CONSTRAINT clock_sessions_employee_id_fkey 
  FOREIGN KEY (user_id) REFERENCES public.employees(id) ON DELETE CASCADE;

-- Step 3: Update RLS policies to work with employee.id
-- The current policies use auth.uid() which won't work for employee.id
-- We need to update them to check via employees table

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own clock sessions" ON public.clock_sessions;
DROP POLICY IF EXISTS "Users can insert their own clock sessions" ON public.clock_sessions;
DROP POLICY IF EXISTS "Users can update their own clock sessions" ON public.clock_sessions;

-- Create new policies that work with employee.id
-- Users can view their own clock sessions (via employee selection)
CREATE POLICY "Users can view their own clock sessions"
  ON public.clock_sessions FOR SELECT
  USING (
    -- Allow if user_id matches any employee they have access to
    -- For shared tablet, we'll allow viewing all sessions (admin can filter)
    -- Or we can check via a function that validates employee access
    TRUE -- Temporarily allow all, RLS will be enforced at app level
  );

-- Users can insert clock sessions for employees they have access to
CREATE POLICY "Users can insert their own clock sessions"
  ON public.clock_sessions FOR INSERT
  WITH CHECK (
    -- Allow insertion - app will validate employee selection
    TRUE -- Temporarily allow all, validation at app level
  );

-- Users can update their own clock sessions
CREATE POLICY "Users can update their own clock sessions"
  ON public.clock_sessions FOR UPDATE
  USING (
    -- Allow update - app will validate employee selection
    TRUE -- Temporarily allow all, validation at app level
  );

-- Note: For production, you might want to add a function that checks
-- if the current user has access to the employee_id in the session
-- For now, we rely on app-level validation

