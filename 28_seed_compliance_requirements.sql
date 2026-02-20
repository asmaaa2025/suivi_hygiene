-- ============================================
-- SEED COMPLIANCE REQUIREMENTS
-- ============================================
-- Creates default compliance requirements for each organization
-- Execute after 27_compliance_documents_rls.sql
-- ============================================

BEGIN;

-- Function to seed compliance requirements for an organization
CREATE OR REPLACE FUNCTION seed_compliance_requirements_for_org(org_id UUID)
RETURNS void AS $$
BEGIN
  -- Insert default requirements if they don't exist
  INSERT INTO public.compliance_requirements (
    organization_id,
    code,
    name,
    frequency_days,
    grace_days,
    active
  ) VALUES
    (org_id, 'MICROBIO', 'Contrôles Microbiologiques', 180, 15, TRUE),
    (org_id, 'PEST_CONTROL', 'Dératisation / Anti-nuisibles', 180, 15, TRUE),
    (org_id, 'COMPLIANCE_AUDIT', 'Audits de Conformité', 180, 15, TRUE)
  ON CONFLICT (organization_id, code) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- Seed for all existing organizations
DO $$
DECLARE
  org_record RECORD;
BEGIN
  FOR org_record IN SELECT id FROM public.organizations
  LOOP
    PERFORM seed_compliance_requirements_for_org(org_record.id);
  END LOOP;
END $$;

-- Also seed for any organization created in the future (via trigger)
CREATE OR REPLACE FUNCTION on_organization_created()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM seed_compliance_requirements_for_org(NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-seed when new organization is created
DROP TRIGGER IF EXISTS trigger_seed_compliance_on_org_create ON public.organizations;
CREATE TRIGGER trigger_seed_compliance_on_org_create
  AFTER INSERT ON public.organizations
  FOR EACH ROW
  EXECUTE FUNCTION on_organization_created();

COMMIT;










