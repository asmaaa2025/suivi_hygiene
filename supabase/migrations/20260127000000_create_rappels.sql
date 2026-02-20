-- Plan de rappel - Gestion des crises sanitaires (PMS)
-- Règlement 178/2002 - Traçabilité et retrait des produits
CREATE TABLE IF NOT EXISTS rappels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations(id),
  produit_nom TEXT NOT NULL,
  lot TEXT,
  fournisseur TEXT,
  motif TEXT NOT NULL,
  date_detection DATE NOT NULL,
  statut TEXT DEFAULT 'ouvert' CHECK (statut IN ('ouvert', 'en_cours', 'clos')),
  actions_prises TEXT,
  contact_ddpp TEXT,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rappels_org ON rappels(organization_id);
CREATE INDEX IF NOT EXISTS idx_rappels_date ON rappels(date_detection);

-- RLS: enable after creating appropriate policy for your auth setup
-- ALTER TABLE rappels ENABLE ROW LEVEL SECURITY;
