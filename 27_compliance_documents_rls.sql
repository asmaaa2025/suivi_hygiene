-- ============================================
-- COMPLIANCE DOCUMENTS RLS POLICIES
-- ============================================
-- Row Level Security for compliance_requirements and compliance_events
-- Execute after 26_compliance_documents_schema.sql
-- ============================================

BEGIN;

-- ============================================
-- 1. Enable RLS
-- ============================================
ALTER TABLE public.compliance_requirements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compliance_events ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 2. Compliance Requirements Policies
-- ============================================
-- Users can read requirements for their organization
CREATE POLICY "Users can read own org requirements"
  ON public.compliance_requirements
  FOR SELECT
  USING (
    organization_id IN (
      SELECT organization_id FROM public.employees WHERE created_by = auth.uid()
    )
  );

-- Only admins can manage requirements
CREATE POLICY "Admins can manage requirements"
  ON public.compliance_requirements
  FOR ALL
  USING (
    organization_id IN (
      SELECT organization_id FROM public.employees WHERE created_by = auth.uid() AND is_admin = TRUE
    )
  );

-- ============================================
-- 3. Compliance Events Policies
-- ============================================
-- Users can read events for their organization
CREATE POLICY "Users can read own org events"
  ON public.compliance_events
  FOR SELECT
  USING (
    organization_id IN (
      SELECT organization_id FROM public.employees WHERE created_by = auth.uid()
    )
  );

-- Users can create events for their organization
CREATE POLICY "Users can create events for own org"
  ON public.compliance_events
  FOR INSERT
  WITH CHECK (
    organization_id IN (
      SELECT organization_id FROM public.employees WHERE created_by = auth.uid()
    )
  );

-- Admins can update/delete events
CREATE POLICY "Admins can manage events"
  ON public.compliance_events
  FOR ALL
  USING (
    organization_id IN (
      SELECT organization_id FROM public.employees WHERE created_by = auth.uid() AND is_admin = TRUE
    )
  );

COMMIT;
