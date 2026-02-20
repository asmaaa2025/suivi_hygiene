-- ============================================
-- NON-CONFORMITIES RLS POLICIES
-- ============================================
-- Row Level Security for NC tables
-- Execute after 29_non_conformities_schema.sql
-- ============================================
-- NOTE: This app uses organization.id = auth.uid() pattern
-- ============================================

BEGIN;

-- ============================================
-- 1. ENABLE RLS ON ALL NC TABLES
-- ============================================

ALTER TABLE public.non_conformities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.non_conformity_causes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.non_conformity_solutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.non_conformity_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.non_conformity_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.non_conformity_attachments ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 2. NON_CONFORMITIES POLICIES
-- ============================================

-- Drop existing policies if any
DROP POLICY IF EXISTS "non_conformities_select_own_org" ON public.non_conformities;
DROP POLICY IF EXISTS "non_conformities_insert_own_org" ON public.non_conformities;
DROP POLICY IF EXISTS "non_conformities_update_own_org" ON public.non_conformities;
DROP POLICY IF EXISTS "non_conformities_delete_own_org" ON public.non_conformities;

-- Users can read NCs for their organization
CREATE POLICY "non_conformities_select_own_org"
  ON public.non_conformities
  FOR SELECT
  USING (organization_id = auth.uid());

-- Users can insert NCs for their organization
CREATE POLICY "non_conformities_insert_own_org"
  ON public.non_conformities
  FOR INSERT
  WITH CHECK (organization_id = auth.uid());

-- Users can update NCs for their organization
CREATE POLICY "non_conformities_update_own_org"
  ON public.non_conformities
  FOR UPDATE
  USING (organization_id = auth.uid())
  WITH CHECK (organization_id = auth.uid());

-- Users can delete NCs for their organization
CREATE POLICY "non_conformities_delete_own_org"
  ON public.non_conformities
  FOR DELETE
  USING (organization_id = auth.uid());

-- ============================================
-- 3. NON_CONFORMITY_CAUSES POLICIES
-- ============================================

DROP POLICY IF EXISTS "nc_causes_select_own_org" ON public.non_conformity_causes;
DROP POLICY IF EXISTS "nc_causes_modify_own_org" ON public.non_conformity_causes;

CREATE POLICY "nc_causes_select_own_org"
  ON public.non_conformity_causes
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.non_conformities
      WHERE non_conformities.id = non_conformity_causes.non_conformity_id
        AND non_conformities.organization_id = auth.uid()
    )
  );

CREATE POLICY "nc_causes_modify_own_org"
  ON public.non_conformity_causes
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.non_conformities
      WHERE non_conformities.id = non_conformity_causes.non_conformity_id
        AND non_conformities.organization_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.non_conformities
      WHERE non_conformities.id = non_conformity_causes.non_conformity_id
        AND non_conformities.organization_id = auth.uid()
    )
  );

-- ============================================
-- 4. NON_CONFORMITY_SOLUTIONS POLICIES
-- ============================================

DROP POLICY IF EXISTS "nc_solutions_select_own_org" ON public.non_conformity_solutions;
DROP POLICY IF EXISTS "nc_solutions_modify_own_org" ON public.non_conformity_solutions;

CREATE POLICY "nc_solutions_select_own_org"
  ON public.non_conformity_solutions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.non_conformities
      WHERE non_conformities.id = non_conformity_solutions.non_conformity_id
        AND non_conformities.organization_id = auth.uid()
    )
  );

CREATE POLICY "nc_solutions_modify_own_org"
  ON public.non_conformity_solutions
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.non_conformities
      WHERE non_conformities.id = non_conformity_solutions.non_conformity_id
        AND non_conformities.organization_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.non_conformities
      WHERE non_conformities.id = non_conformity_solutions.non_conformity_id
        AND non_conformities.organization_id = auth.uid()
    )
  );

-- ============================================
-- 5. NON_CONFORMITY_ACTIONS POLICIES
-- ============================================

DROP POLICY IF EXISTS "nc_actions_select_own_org" ON public.non_conformity_actions;
DROP POLICY IF EXISTS "nc_actions_modify_own_org" ON public.non_conformity_actions;

CREATE POLICY "nc_actions_select_own_org"
  ON public.non_conformity_actions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.non_conformities
      WHERE non_conformities.id = non_conformity_actions.non_conformity_id
        AND non_conformities.organization_id = auth.uid()
    )
  );

CREATE POLICY "nc_actions_modify_own_org"
  ON public.non_conformity_actions
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.non_conformities
      WHERE non_conformities.id = non_conformity_actions.non_conformity_id
        AND non_conformities.organization_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.non_conformities
      WHERE non_conformities.id = non_conformity_actions.non_conformity_id
        AND non_conformities.organization_id = auth.uid()
    )
  );

-- ============================================
-- 6. NON_CONFORMITY_VERIFICATIONS POLICIES
-- ============================================

DROP POLICY IF EXISTS "nc_verifications_select_own_org" ON public.non_conformity_verifications;
DROP POLICY IF EXISTS "nc_verifications_modify_own_org" ON public.non_conformity_verifications;

CREATE POLICY "nc_verifications_select_own_org"
  ON public.non_conformity_verifications
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.non_conformities
      WHERE non_conformities.id = non_conformity_verifications.non_conformity_id
        AND non_conformities.organization_id = auth.uid()
    )
  );

CREATE POLICY "nc_verifications_modify_own_org"
  ON public.non_conformity_verifications
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.non_conformities
      WHERE non_conformities.id = non_conformity_verifications.non_conformity_id
        AND non_conformities.organization_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.non_conformities
      WHERE non_conformities.id = non_conformity_verifications.non_conformity_id
        AND non_conformities.organization_id = auth.uid()
    )
  );

-- ============================================
-- 7. NON_CONFORMITY_ATTACHMENTS POLICIES
-- ============================================

DROP POLICY IF EXISTS "nc_attachments_select_own_org" ON public.non_conformity_attachments;
DROP POLICY IF EXISTS "nc_attachments_modify_own_org" ON public.non_conformity_attachments;

CREATE POLICY "nc_attachments_select_own_org"
  ON public.non_conformity_attachments
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.non_conformities
      WHERE non_conformities.id = non_conformity_attachments.non_conformity_id
        AND non_conformities.organization_id = auth.uid()
    )
  );

CREATE POLICY "nc_attachments_modify_own_org"
  ON public.non_conformity_attachments
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.non_conformities
      WHERE non_conformities.id = non_conformity_attachments.non_conformity_id
        AND non_conformities.organization_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.non_conformities
      WHERE non_conformities.id = non_conformity_attachments.non_conformity_id
        AND non_conformities.organization_id = auth.uid()
    )
  );

COMMIT;










