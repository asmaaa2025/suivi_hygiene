-- ============================================
-- FIX EMPLOYEES RLS POLICY
-- ============================================
-- Problem: Current RLS policy only allows users to see employees they created
-- Solution: Allow users to see ALL employees in their organization
-- Business model: ONE auth account per organization, multiple employees per org
-- ============================================

BEGIN;

-- Drop existing policies
DROP POLICY IF EXISTS "employees_select_policy" ON public.employees;
DROP POLICY IF EXISTS "employees_insert_policy" ON public.employees;
DROP POLICY IF EXISTS "employees_update_policy" ON public.employees;
DROP POLICY IF EXISTS "employees_delete_policy" ON public.employees;

-- ============================================
-- NEW EMPLOYEES POLICIES (Organization-based)
-- ============================================

-- SELECT: Users can see ALL employees in their organization
-- Organization ID = auth.uid() (one auth account per organization)
CREATE POLICY "employees_select_policy" ON public.employees
  FOR SELECT 
  USING (
    organization_id = (
      SELECT id FROM public.organizations 
      WHERE id = auth.uid()
      LIMIT 1
    )
  );

-- INSERT: Users can create employees in their organization
CREATE POLICY "employees_insert_policy" ON public.employees
  FOR INSERT 
  WITH CHECK (
    organization_id = (
      SELECT id FROM public.organizations 
      WHERE id = auth.uid()
      LIMIT 1
    )
    AND created_by = auth.uid()
  );

-- UPDATE: Users can update employees in their organization
CREATE POLICY "employees_update_policy" ON public.employees
  FOR UPDATE 
  USING (
    organization_id = (
      SELECT id FROM public.organizations 
      WHERE id = auth.uid()
      LIMIT 1
    )
  );

-- DELETE: Users can delete employees in their organization
CREATE POLICY "employees_delete_policy" ON public.employees
  FOR DELETE 
  USING (
    organization_id = (
      SELECT id FROM public.organizations 
      WHERE id = auth.uid()
      LIMIT 1
    )
  );

COMMIT;

-- ============================================
-- VERIFICATION
-- ============================================
-- After running this migration:
-- 1. Users should be able to see ALL employees in their organization
-- 2. Users can create employees in their organization
-- 3. Users can update/delete employees in their organization
-- 4. Test: Create an employee, then verify it appears in the list
-- ============================================

