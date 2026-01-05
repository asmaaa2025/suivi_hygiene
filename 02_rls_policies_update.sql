-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES - UPDATE SCRIPT
-- ============================================
-- This script drops existing policies and recreates them
-- Run this if you get "policy already exists" errors
-- ============================================

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "organizations_select_policy" ON public.organizations;
DROP POLICY IF EXISTS "organizations_insert_policy" ON public.organizations;
DROP POLICY IF EXISTS "organizations_update_policy" ON public.organizations;

DROP POLICY IF EXISTS "employees_select_policy" ON public.employees;
DROP POLICY IF EXISTS "employees_insert_policy" ON public.employees;
DROP POLICY IF EXISTS "employees_update_policy" ON public.employees;
DROP POLICY IF EXISTS "employees_delete_policy" ON public.employees;

DROP POLICY IF EXISTS "suppliers_select_policy" ON public.suppliers;
DROP POLICY IF EXISTS "suppliers_insert_policy" ON public.suppliers;
DROP POLICY IF EXISTS "suppliers_update_policy" ON public.suppliers;
DROP POLICY IF EXISTS "suppliers_delete_policy" ON public.suppliers;

DROP POLICY IF EXISTS "supplier_products_select_policy" ON public.supplier_products;
DROP POLICY IF EXISTS "supplier_products_insert_policy" ON public.supplier_products;
DROP POLICY IF EXISTS "supplier_products_update_policy" ON public.supplier_products;
DROP POLICY IF EXISTS "supplier_products_delete_policy" ON public.supplier_products;

DROP POLICY IF EXISTS "non_conformities_select_policy" ON public.non_conformities;
DROP POLICY IF EXISTS "non_conformities_insert_policy" ON public.non_conformities;
DROP POLICY IF EXISTS "non_conformities_update_policy" ON public.non_conformities;

DROP POLICY IF EXISTS "cleaning_task_runs_select_policy" ON public.cleaning_task_runs;
DROP POLICY IF EXISTS "cleaning_task_runs_insert_policy" ON public.cleaning_task_runs;
DROP POLICY IF EXISTS "cleaning_task_runs_update_policy" ON public.cleaning_task_runs;

DROP POLICY IF EXISTS "audit_log_select_policy" ON public.audit_log;

-- ============================================
-- ORGANIZATIONS POLICIES
-- ============================================
-- Users can read all organizations (simplified - in production, restrict by membership)
CREATE POLICY "organizations_select_policy" ON public.organizations
  FOR SELECT USING (true);

-- Users can create organizations
CREATE POLICY "organizations_insert_policy" ON public.organizations
  FOR INSERT WITH CHECK (true);

-- Users can update organizations (restrict in production)
CREATE POLICY "organizations_update_policy" ON public.organizations
  FOR UPDATE USING (true);

-- ============================================
-- EMPLOYEES POLICIES (FIXED - NO RECURSION)
-- ============================================
-- Users can read employees they created (avoids recursion)
CREATE POLICY "employees_select_policy" ON public.employees
  FOR SELECT USING (created_by = auth.uid());

-- Admins can create employees
CREATE POLICY "employees_insert_policy" ON public.employees
  FOR INSERT WITH CHECK (created_by = auth.uid());

-- Admins can update employees they created
CREATE POLICY "employees_update_policy" ON public.employees
  FOR UPDATE USING (created_by = auth.uid());

-- Admins can delete employees they created
CREATE POLICY "employees_delete_policy" ON public.employees
  FOR DELETE USING (created_by = auth.uid());

-- ============================================
-- SUPPLIERS POLICIES (FIXED - NO RECURSION)
-- ============================================
-- Users can read their own suppliers
CREATE POLICY "suppliers_select_policy" ON public.suppliers
  FOR SELECT USING (owner_id = auth.uid());

-- Users can create suppliers
CREATE POLICY "suppliers_insert_policy" ON public.suppliers
  FOR INSERT WITH CHECK (owner_id = auth.uid());

-- Users can update their suppliers
CREATE POLICY "suppliers_update_policy" ON public.suppliers
  FOR UPDATE USING (owner_id = auth.uid());

-- Users can delete their suppliers
CREATE POLICY "suppliers_delete_policy" ON public.suppliers
  FOR DELETE USING (owner_id = auth.uid());

-- ============================================
-- SUPPLIER_PRODUCTS POLICIES
-- ============================================
-- Users can read supplier-products for their suppliers
CREATE POLICY "supplier_products_select_policy" ON public.supplier_products
  FOR SELECT USING (
    supplier_id IN (
      SELECT id FROM public.suppliers WHERE owner_id = auth.uid()
    )
  );

-- Users can create supplier-products for their suppliers
CREATE POLICY "supplier_products_insert_policy" ON public.supplier_products
  FOR INSERT WITH CHECK (
    supplier_id IN (
      SELECT id FROM public.suppliers WHERE owner_id = auth.uid()
    )
  );

-- Users can update their supplier-products
CREATE POLICY "supplier_products_update_policy" ON public.supplier_products
  FOR UPDATE USING (
    supplier_id IN (
      SELECT id FROM public.suppliers WHERE owner_id = auth.uid()
    )
  );

-- Users can delete their supplier-products
CREATE POLICY "supplier_products_delete_policy" ON public.supplier_products
  FOR DELETE USING (
    supplier_id IN (
      SELECT id FROM public.suppliers WHERE owner_id = auth.uid()
    )
  );

-- ============================================
-- NON_CONFORMITIES POLICIES
-- ============================================
-- Users can read non-conformities for their receptions
CREATE POLICY "non_conformities_select_policy" ON public.non_conformities
  FOR SELECT USING (
    reception_id IN (
      SELECT id FROM public.receptions WHERE owner_id = auth.uid()
    )
  );

-- Users can create non-conformities
CREATE POLICY "non_conformities_insert_policy" ON public.non_conformities
  FOR INSERT WITH CHECK (created_by = auth.uid());

-- Users can update their non-conformities
CREATE POLICY "non_conformities_update_policy" ON public.non_conformities
  FOR UPDATE USING (created_by = auth.uid());

-- ============================================
-- CLEANING_TASK_RUNS POLICIES
-- ============================================
-- Users can read task runs for their tasks
CREATE POLICY "cleaning_task_runs_select_policy" ON public.cleaning_task_runs
  FOR SELECT USING (
    task_id IN (
      SELECT id FROM public.taches_nettoyage WHERE owner_id = auth.uid()
    )
  );

-- Users can create task runs
CREATE POLICY "cleaning_task_runs_insert_policy" ON public.cleaning_task_runs
  FOR INSERT WITH CHECK (done_by_user_id = auth.uid());

-- Users can update their task runs
CREATE POLICY "cleaning_task_runs_update_policy" ON public.cleaning_task_runs
  FOR UPDATE USING (done_by_user_id = auth.uid());

-- ============================================
-- AUDIT_LOG POLICIES (FIXED - NO RECURSION)
-- ============================================
-- Users can read audit logs where they are the actor
CREATE POLICY "audit_log_select_policy" ON public.audit_log
  FOR SELECT USING (
    actor_user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.employees 
      WHERE id = audit_log.actor_employee_id 
      AND created_by = auth.uid()
    )
  );

-- System can create audit logs (via service role or function)
-- Note: In production, use service role for inserts or create a function

