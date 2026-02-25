-- ============================================
-- COMPLIANCE DOCUMENTS SCHEMA
-- ============================================
-- Creates compliance_requirements and compliance_events tables
-- Adds compliance columns to existing documents table
-- Execute before 27_compliance_documents_rls.sql
-- ============================================

BEGIN;

-- ============================================
-- 1. Compliance Requirements Table
-- ============================================
CREATE TABLE IF NOT EXISTS public.compliance_requirements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  frequency_days INTEGER NOT NULL DEFAULT 180,
  grace_days INTEGER NOT NULL DEFAULT 15,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(organization_id, code)
);

-- ============================================
-- 2. Compliance Events Table
-- ============================================
CREATE TABLE IF NOT EXISTS public.compliance_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  requirement_id UUID NOT NULL REFERENCES public.compliance_requirements(id) ON DELETE CASCADE,
  event_date DATE NOT NULL,
  document_id UUID REFERENCES public.documents(id) ON DELETE SET NULL,
  notes TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 3. Add compliance columns to documents table
-- ============================================
-- Add title column if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'documents' AND column_name = 'titre'
  ) THEN
    ALTER TABLE public.documents ADD COLUMN titre TEXT;
  END IF;
END $$;

-- Add notes column if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'documents' AND column_name = 'notes'
  ) THEN
    ALTER TABLE public.documents ADD COLUMN notes TEXT;
  END IF;
END $$;

-- Add organization_id column if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'documents' AND column_name = 'organization_id'
  ) THEN
    ALTER TABLE public.documents ADD COLUMN organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
  END IF;
END $$;

-- ============================================
-- 4. Indexes
-- ============================================
CREATE INDEX IF NOT EXISTS idx_compliance_requirements_org
  ON public.compliance_requirements(organization_id);

CREATE INDEX IF NOT EXISTS idx_compliance_events_org
  ON public.compliance_events(organization_id);

CREATE INDEX IF NOT EXISTS idx_compliance_events_requirement
  ON public.compliance_events(requirement_id);

CREATE INDEX IF NOT EXISTS idx_compliance_events_date
  ON public.compliance_events(event_date DESC);

CREATE INDEX IF NOT EXISTS idx_documents_organization
  ON public.documents(organization_id);

COMMIT;
