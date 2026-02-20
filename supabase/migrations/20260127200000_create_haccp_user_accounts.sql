-- Table pour les comptes utilisateurs HACCPilot (distinct du registre personnel)
-- Permet à l'admin de créer des comptes de connexion à l'app

CREATE TABLE IF NOT EXISTS public.haccp_user_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  auth_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  display_name TEXT,
  organization_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL,
  personnel_id UUID, -- Lien optionnel vers registre personnel (FK si table existe)
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_haccp_user_accounts_email ON public.haccp_user_accounts(email);
CREATE INDEX IF NOT EXISTS idx_haccp_user_accounts_created_by ON public.haccp_user_accounts(created_by);
CREATE INDEX IF NOT EXISTS idx_haccp_user_accounts_org ON public.haccp_user_accounts(organization_id);

ALTER TABLE public.haccp_user_accounts ENABLE ROW LEVEL SECURITY;

-- RLS: l'admin peut gérer les comptes qu'il a créés
CREATE POLICY "haccp_user_accounts_select"
ON public.haccp_user_accounts FOR SELECT
TO authenticated
USING (created_by = auth.uid());

CREATE POLICY "haccp_user_accounts_insert"
ON public.haccp_user_accounts FOR INSERT
TO authenticated
WITH CHECK (created_by = auth.uid());

CREATE POLICY "haccp_user_accounts_update"
ON public.haccp_user_accounts FOR UPDATE
TO authenticated
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

CREATE POLICY "haccp_user_accounts_delete"
ON public.haccp_user_accounts FOR DELETE
TO authenticated
USING (created_by = auth.uid());

COMMENT ON TABLE public.haccp_user_accounts IS 'Comptes utilisateurs HACCPilot créés par l''admin - distinct du registre personnel';
