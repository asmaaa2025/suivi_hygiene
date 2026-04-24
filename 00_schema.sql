-- ============================================
-- CONSOLIDATED SUPABASE SCHEMA
-- ============================================
-- This file contains all database schema definitions:
-- - Extensions
-- - Tables with complete column definitions
-- - Indexes
-- - Functions
-- - Triggers
-- ============================================
-- Execute this file first in Supabase SQL Editor
-- ============================================

-- ============================================
-- EXTENSIONS
-- ============================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- TABLES
-- ============================================

-- ============================================
-- 1. APPAREILS (Devices/Temperature Equipment)
-- ============================================
CREATE TABLE IF NOT EXISTS public.appareils (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nom TEXT NOT NULL,
  temp_min NUMERIC(5,2),
  temp_max NUMERIC(5,2),
  type_appareil TEXT,
  seuil_min NUMERIC(5,2),
  seuil_max NUMERIC(5,2),
  description TEXT,
  owner_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  date_creation TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 2. TEMPERATURES (Temperature Logs)
-- ============================================
CREATE TABLE IF NOT EXISTS public.temperatures (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  appareil_id UUID REFERENCES public.appareils(id) ON DELETE CASCADE,
  appareil TEXT, -- Legacy column for compatibility
  temperature NUMERIC(5,2) NOT NULL,
  remarque TEXT,
  commentaire TEXT,
  conforme BOOLEAN DEFAULT true,
  photo_url TEXT, -- URL of photo in Supabase Storage
  photo_path TEXT, -- Legacy column name (will be migrated to photo_url)
  date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  owner_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Legacy column
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Migrate photo_path to photo_url if needed
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'temperatures' 
    AND column_name = 'photo_path'
    AND column_name != 'photo_url'
  ) THEN
    UPDATE public.temperatures 
    SET photo_url = photo_path 
    WHERE photo_url IS NULL AND photo_path IS NOT NULL;
  END IF;
END $$;

-- ============================================
-- 3. NETTOYAGES (Cleaning Records)
-- ============================================
CREATE TABLE IF NOT EXISTS public.nettoyages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  task_id UUID REFERENCES public.taches_nettoyage(id) ON DELETE CASCADE, -- Legacy column
  tache_id UUID REFERENCES public.taches_nettoyage(id) ON DELETE CASCADE,
  action TEXT, -- Legacy column
  remarque TEXT,
  statut TEXT DEFAULT 'fait',
  done BOOLEAN DEFAULT FALSE,
  done_at TIMESTAMPTZ,
  conforme BOOLEAN,
  photo_url TEXT,
  date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  owner_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Legacy column
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Migrate task_id to tache_id if needed
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'nettoyages' 
    AND column_name = 'task_id'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'nettoyages' 
    AND column_name = 'tache_id'
  ) THEN
    UPDATE public.nettoyages 
    SET tache_id = task_id 
    WHERE tache_id IS NULL AND task_id IS NOT NULL;
  END IF;
  
  -- Set done = true if done_at is not null
  UPDATE public.nettoyages 
  SET done = TRUE 
  WHERE done_at IS NOT NULL AND done IS FALSE;
END $$;

-- ============================================
-- 4. TACHES_NETTOYAGE (Cleaning Tasks/Templates)
-- ============================================
CREATE TABLE IF NOT EXISTS public.taches_nettoyage (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nom TEXT NOT NULL,
  description TEXT,
  frequence TEXT,
  recurrence_type TEXT CHECK (recurrence_type IN ('daily', 'weekly', 'monthly')),
  interval INTEGER DEFAULT 1,
  weekdays INTEGER[], -- Array of 1-7 (Mon-Sun), only for weekly
  day_of_month INTEGER CHECK (day_of_month >= 1 AND day_of_month <= 31), -- Only for monthly
  time_of_day TEXT, -- Format: "HH:mm"
  duree_estimee INTEGER,
  is_active BOOLEAN DEFAULT TRUE,
  owner_id UUID DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE SET NULL, -- Nullable for system templates
  date_creation TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 5. FOURNISSEURS (Suppliers)
-- ============================================
CREATE TABLE IF NOT EXISTS public.fournisseurs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nom TEXT NOT NULL,
  adresse TEXT,
  telephone TEXT,
  email TEXT,
  owner_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE, -- Legacy column
  date_creation TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Migrate user_id to owner_id if needed
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fournisseurs' 
    AND column_name = 'user_id'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'fournisseurs' 
    AND column_name = 'owner_id'
  ) THEN
    UPDATE public.fournisseurs 
    SET owner_id = user_id 
    WHERE owner_id IS NULL AND user_id IS NOT NULL;
  END IF;
END $$;

-- ============================================
-- 6. RECEPTIONS (Receptions/Receipts)
-- ============================================
CREATE TABLE IF NOT EXISTS public.receptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  produit_id UUID REFERENCES public.produits(id) ON DELETE SET NULL,
  fournisseur TEXT, -- Supplier name (can be changed to UUID FK later)
  produit TEXT, -- Legacy column
  article TEXT, -- For compatibility
  lot TEXT,
  quantite TEXT NOT NULL,
  dluo TIMESTAMPTZ, -- Date limite d'utilisation optimale
  temperature NUMERIC(5,2),
  statut TEXT DEFAULT 'Conforme',
  conforme INTEGER DEFAULT 1, -- 1 = Conforme, 0 = Non conforme
  remarque TEXT,
  photo_url TEXT,
  photo_path TEXT, -- Legacy column
  date TIMESTAMPTZ DEFAULT NOW(),
  received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  owner_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Legacy column
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE, -- Legacy column
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Migrate legacy columns if needed
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receptions' 
    AND column_name = 'photo_path'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receptions' 
    AND column_name = 'photo_url'
  ) THEN
    UPDATE public.receptions 
    SET photo_url = photo_path 
    WHERE photo_url IS NULL AND photo_path IS NOT NULL;
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receptions' 
    AND column_name = 'user_id'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receptions' 
    AND column_name = 'owner_id'
  ) THEN
    UPDATE public.receptions 
    SET owner_id = user_id 
    WHERE owner_id IS NULL AND user_id IS NOT NULL;
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receptions' 
    AND column_name = 'created_by'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receptions' 
    AND column_name = 'owner_id'
  ) THEN
    UPDATE public.receptions 
    SET owner_id = created_by 
    WHERE owner_id IS NULL AND created_by IS NOT NULL;
  END IF;
  
  -- Backfill received_at from date if needed
  UPDATE public.receptions 
  SET received_at = date 
  WHERE received_at IS NULL AND date IS NOT NULL;
END $$;

-- ============================================
-- 7. FRITEUSES (Fryers)
-- ============================================
CREATE TABLE IF NOT EXISTS public.friteuses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nom TEXT NOT NULL,
  capacite TEXT,
  type_huile TEXT,
  date_installation DATE,
  owner_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE, -- Legacy column
  date_creation TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Migrate user_id to owner_id if needed
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'friteuses' 
    AND column_name = 'user_id'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'friteuses' 
    AND column_name = 'owner_id'
  ) THEN
    UPDATE public.friteuses 
    SET owner_id = user_id 
    WHERE owner_id IS NULL AND user_id IS NOT NULL;
  END IF;
END $$;

-- ============================================
-- 8. OIL_CHANGES (Oil Change Records)
-- ============================================
CREATE TABLE IF NOT EXISTS public.oil_changes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  friteuse_id UUID REFERENCES public.friteuses(id) ON DELETE CASCADE,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  type_huile TEXT,
  quantite NUMERIC(5,2) NOT NULL,
  responsable TEXT,
  remarque TEXT,
  photo_url TEXT,
  owner_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Legacy column
  date_changement TIMESTAMPTZ, -- Legacy column
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Migrate legacy columns if needed
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'oil_changes' 
    AND column_name = 'created_by'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'oil_changes' 
    AND column_name = 'owner_id'
  ) THEN
    UPDATE public.oil_changes 
    SET owner_id = created_by 
    WHERE owner_id IS NULL AND created_by IS NOT NULL;
  END IF;
  
  -- Backfill changed_at from date_changement if needed
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'oil_changes' 
    AND column_name = 'date_changement'
  ) THEN
    UPDATE public.oil_changes 
    SET changed_at = date_changement 
    WHERE changed_at IS NULL AND date_changement IS NOT NULL;
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'oil_changes' 
    AND column_name = 'created_at'
  ) THEN
    UPDATE public.oil_changes 
    SET changed_at = created_at 
    WHERE changed_at IS NULL AND created_at IS NOT NULL;
  END IF;
END $$;

-- ============================================
-- 9. PRODUITS (Products)
-- ============================================
CREATE TABLE IF NOT EXISTS public.produits (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nom TEXT NOT NULL,
  description TEXT,
  type_produit TEXT DEFAULT 'fini', -- fini, prepare, ouverture, decongelation
  categorie TEXT,
  prix_unitaire NUMERIC(10,2),
  unite TEXT,
  dlc TEXT, -- Date limite de consommation
  dlc_jours INTEGER,
  lot TEXT,
  poids NUMERIC(10,2),
  date_fabrication TIMESTAMPTZ DEFAULT NOW(),
  surgelagable BOOLEAN DEFAULT FALSE,
  dlc_surgelation_jours INTEGER,
  ingredients TEXT,
  quantite TEXT,
  origine_viande TEXT,
  allergenes TEXT,
  actif BOOLEAN DEFAULT TRUE,
  fournisseur_id UUID REFERENCES public.fournisseurs(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE, -- Legacy column
  date_creation TIMESTAMPTZ DEFAULT NOW(),
  date_modification TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Migrate user_id to owner_id if needed
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'produits' 
    AND column_name = 'user_id'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'produits' 
    AND column_name = 'owner_id'
  ) THEN
    UPDATE public.produits 
    SET owner_id = user_id 
    WHERE owner_id IS NULL AND user_id IS NOT NULL;
  END IF;
  
  -- Backfill dates if needed
  UPDATE public.produits 
  SET 
    date_fabrication = COALESCE(date_fabrication, created_at),
    date_modification = COALESCE(date_modification, created_at),
    type_produit = COALESCE(type_produit, 'fini')
  WHERE date_fabrication IS NULL OR date_modification IS NULL OR type_produit IS NULL;
END $$;

-- ============================================
-- 10. DOCUMENTS (Documents Metadata)
-- ============================================
CREATE TABLE IF NOT EXISTS public.documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nom TEXT NOT NULL,
  titre TEXT, -- Legacy column
  description TEXT,
  categorie TEXT,
  type_document TEXT,
  fichier_url TEXT, -- Storage path or URL
  chemin TEXT, -- Legacy column name
  taille INTEGER, -- File size in bytes
  owner_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE, -- Legacy column
  date TIMESTAMPTZ DEFAULT NOW(),
  date_creation TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Migrate legacy columns if needed
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'documents' 
    AND column_name = 'chemin'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'documents' 
    AND column_name = 'fichier_url'
  ) THEN
    UPDATE public.documents 
    SET fichier_url = chemin 
    WHERE fichier_url IS NULL AND chemin IS NOT NULL;
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'documents' 
    AND column_name = 'user_id'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'documents' 
    AND column_name = 'owner_id'
  ) THEN
    UPDATE public.documents 
    SET owner_id = user_id 
    WHERE owner_id IS NULL AND user_id IS NOT NULL;
  END IF;
END $$;

-- ============================================
-- 11. LABEL_PRINTS (Zebra Print History)
-- ============================================
CREATE TABLE IF NOT EXISTS public.label_prints (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  produit_id UUID REFERENCES public.produits(id) ON DELETE SET NULL,
  produit_nom TEXT NOT NULL,
  lot TEXT,
  weight TEXT,
  prepared_by TEXT,
  manufactured_at TEXT,
  dlc TEXT,
  dluo TEXT,
  zpl_payload TEXT NOT NULL,
  zpl TEXT, -- Legacy column name
  success BOOLEAN DEFAULT FALSE,
  error_message TEXT,
  status TEXT DEFAULT 'success', -- success, error
  printed_at TIMESTAMPTZ DEFAULT NOW(),
  owner_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Legacy column
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Migrate legacy columns if needed
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'label_prints' 
    AND column_name = 'created_by'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'label_prints' 
    AND column_name = 'owner_id'
  ) THEN
    UPDATE public.label_prints 
    SET owner_id = created_by 
    WHERE owner_id IS NULL AND created_by IS NOT NULL;
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'label_prints' 
    AND column_name = 'zpl'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'label_prints' 
    AND column_name = 'zpl_payload'
  ) THEN
    UPDATE public.label_prints 
    SET zpl_payload = zpl 
    WHERE zpl_payload IS NULL AND zpl IS NOT NULL;
  END IF;
END $$;

-- Legacy table name alias (label_print_history)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'label_print_history'
  ) THEN
    CREATE VIEW public.label_print_history AS SELECT * FROM public.label_prints;
  END IF;
END $$;

-- ============================================
-- INDEXES
-- ============================================

-- Appareils indexes
CREATE INDEX IF NOT EXISTS idx_appareils_owner_id ON public.appareils(owner_id);
CREATE INDEX IF NOT EXISTS idx_appareils_nom ON public.appareils(nom);
CREATE INDEX IF NOT EXISTS idx_appareils_type ON public.appareils(type_appareil);
CREATE INDEX IF NOT EXISTS idx_appareils_created_at ON public.appareils(created_at DESC);

-- Temperatures indexes
-- Note: idx_temperatures_owner_id removed - covered by idx_temperatures_owner_date (left-prefix rule)
CREATE INDEX IF NOT EXISTS idx_temperatures_owner_date ON public.temperatures(owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_temperatures_appareil_id ON public.temperatures(appareil_id);
CREATE INDEX IF NOT EXISTS idx_temperatures_appareil ON public.temperatures(appareil);
CREATE INDEX IF NOT EXISTS idx_temperatures_date ON public.temperatures(date DESC);
CREATE INDEX IF NOT EXISTS idx_temperatures_created_at ON public.temperatures(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_temperatures_created_by ON public.temperatures(created_by);

-- Nettoyages indexes
-- Note: idx_nettoyages_owner_id removed - covered by idx_nettoyages_owner_date (left-prefix rule)
CREATE INDEX IF NOT EXISTS idx_nettoyages_owner_date ON public.nettoyages(owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_nettoyages_task_id ON public.nettoyages(task_id);
CREATE INDEX IF NOT EXISTS idx_nettoyages_tache_id ON public.nettoyages(tache_id);
CREATE INDEX IF NOT EXISTS idx_nettoyages_created_at ON public.nettoyages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_nettoyages_done ON public.nettoyages(done);
CREATE INDEX IF NOT EXISTS idx_nettoyages_done_at ON public.nettoyages(done_at DESC);
CREATE INDEX IF NOT EXISTS idx_nettoyages_created_by ON public.nettoyages(created_by);

-- Taches nettoyage indexes
CREATE INDEX IF NOT EXISTS idx_taches_nettoyage_owner_id ON public.taches_nettoyage(owner_id);
CREATE INDEX IF NOT EXISTS idx_taches_nettoyage_active ON public.taches_nettoyage(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_taches_nettoyage_recurrence ON public.taches_nettoyage(recurrence_type, is_active);
CREATE INDEX IF NOT EXISTS idx_taches_nettoyage_nom ON public.taches_nettoyage(nom);

-- Fournisseurs indexes
CREATE INDEX IF NOT EXISTS idx_fournisseurs_owner_id ON public.fournisseurs(owner_id);
CREATE INDEX IF NOT EXISTS idx_fournisseurs_user_id ON public.fournisseurs(user_id);
CREATE INDEX IF NOT EXISTS idx_fournisseurs_nom ON public.fournisseurs(nom);

-- Receptions indexes
-- Note: idx_receptions_owner_id removed - covered by idx_receptions_owner_date (left-prefix rule)
CREATE INDEX IF NOT EXISTS idx_receptions_owner_date ON public.receptions(owner_id, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_receptions_produit_id ON public.receptions(produit_id);
CREATE INDEX IF NOT EXISTS idx_receptions_fournisseur ON public.receptions(fournisseur);
CREATE INDEX IF NOT EXISTS idx_receptions_date ON public.receptions(date DESC);
CREATE INDEX IF NOT EXISTS idx_receptions_received_at ON public.receptions(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_receptions_created_by ON public.receptions(created_by);
CREATE INDEX IF NOT EXISTS idx_receptions_user_id ON public.receptions(user_id);

-- Friteuses indexes
CREATE INDEX IF NOT EXISTS idx_friteuses_owner_id ON public.friteuses(owner_id);
CREATE INDEX IF NOT EXISTS idx_friteuses_user_id ON public.friteuses(user_id);
CREATE INDEX IF NOT EXISTS idx_friteuses_nom ON public.friteuses(nom);

-- Oil changes indexes
-- Note: idx_oil_changes_owner_id removed - covered by idx_oil_changes_owner_date (left-prefix rule)
CREATE INDEX IF NOT EXISTS idx_oil_changes_owner_date ON public.oil_changes(owner_id, changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_oil_changes_friteuse_id ON public.oil_changes(friteuse_id);
CREATE INDEX IF NOT EXISTS idx_oil_changes_changed_at ON public.oil_changes(changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_oil_changes_created_by ON public.oil_changes(created_by);

-- Produits indexes
-- Note: idx_produits_owner_id removed - covered by idx_produits_owner_created (left-prefix rule)
CREATE INDEX IF NOT EXISTS idx_produits_owner_created ON public.produits(owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_produits_user_id ON public.produits(user_id);
CREATE INDEX IF NOT EXISTS idx_produits_nom ON public.produits(nom);
CREATE INDEX IF NOT EXISTS idx_produits_fournisseur_id ON public.produits(fournisseur_id);

-- Documents indexes
CREATE INDEX IF NOT EXISTS idx_documents_owner_id ON public.documents(owner_id);
CREATE INDEX IF NOT EXISTS idx_documents_user_id ON public.documents(user_id);
CREATE INDEX IF NOT EXISTS idx_documents_date ON public.documents(date DESC);
CREATE INDEX IF NOT EXISTS idx_documents_titre ON public.documents(titre);
CREATE INDEX IF NOT EXISTS idx_documents_type ON public.documents(type_document);

-- Label prints indexes
-- Note: idx_label_prints_owner_id removed - covered by idx_label_prints_owner_date (left-prefix rule)
CREATE INDEX IF NOT EXISTS idx_label_prints_owner_date ON public.label_prints(owner_id, printed_at DESC);
CREATE INDEX IF NOT EXISTS idx_label_prints_produit_id ON public.label_prints(produit_id);
CREATE INDEX IF NOT EXISTS idx_label_prints_printed_at ON public.label_prints(printed_at DESC);
CREATE INDEX IF NOT EXISTS idx_label_prints_created_by ON public.label_prints(created_by);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Before deleting a product: keep readable product name on reception rows (produit_id → SET NULL)
CREATE OR REPLACE FUNCTION public.trg_snapshot_produit_nom_before_produit_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.receptions r
  SET
    produit = COALESCE(NULLIF(TRIM(r.produit), ''), OLD.nom),
    article = COALESCE(NULLIF(TRIM(r.article), ''), OLD.nom)
  WHERE r.produit_id = OLD.id;
  RETURN OLD;
END;
$$;

-- ============================================
-- TRIGGERS
-- ============================================

-- Triggers for updated_at columns
CREATE TRIGGER update_appareils_updated_at
  BEFORE UPDATE ON public.appareils
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_fournisseurs_updated_at
  BEFORE UPDATE ON public.fournisseurs
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_friteuses_updated_at
  BEFORE UPDATE ON public.friteuses
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_produits_updated_at
  BEFORE UPDATE ON public.produits
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS snapshot_produit_nom_before_produit_delete ON public.produits;
CREATE TRIGGER snapshot_produit_nom_before_produit_delete
  BEFORE DELETE ON public.produits
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_snapshot_produit_nom_before_produit_delete();

CREATE TRIGGER update_documents_updated_at
  BEFORE UPDATE ON public.documents
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_nettoyages_updated_at
  BEFORE UPDATE ON public.nettoyages
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_taches_nettoyage_updated_at
  BEFORE UPDATE ON public.taches_nettoyage
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================
-- COMMENTS
-- ============================================
COMMENT ON TABLE public.appareils IS 'Temperature monitoring devices (fridges, freezers, etc.)';
COMMENT ON TABLE public.temperatures IS 'Temperature log entries';
COMMENT ON TABLE public.nettoyages IS 'Cleaning and disinfection records';
COMMENT ON TABLE public.taches_nettoyage IS 'Recurring cleaning task templates';
COMMENT ON TABLE public.fournisseurs IS 'Suppliers';
COMMENT ON TABLE public.receptions IS 'Product reception records';
COMMENT ON TABLE public.friteuses IS 'Fryers';
COMMENT ON TABLE public.oil_changes IS 'Oil change records for fryers';
COMMENT ON TABLE public.produits IS 'Products';
COMMENT ON TABLE public.documents IS 'Document metadata (files stored in Storage)';
COMMENT ON TABLE public.label_prints IS 'Zebra label print history';

-- ============================================
-- END OF SCHEMA
-- ============================================

