-- ============================================
-- CONSOLIDATED ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================
-- This file contains all RLS enablement and policies
-- Execute this AFTER 00_schema.sql
-- ============================================

BEGIN;

-- ============================================
-- STEP 1: ENSURE owner_id COLUMNS EXIST AND ARE NOT NULL
-- ============================================
-- This section ensures all tables have owner_id columns with proper constraints

DO $$
DECLARE
  first_user_id UUID;
  null_count INTEGER;
  table_name TEXT;
BEGIN
  -- Get first user for assigning NULL values (if any exist)
  SELECT id INTO first_user_id FROM auth.users ORDER BY created_at LIMIT 1;
  
  -- List of all tables that need strict RLS with owner_id
  FOR table_name IN 
    SELECT unnest(ARRAY[
      'produits',
      'friteuses',
      'oil_changes',
      'temperatures',
      'appareils',
      'nettoyages',
      'receptions',
      'fournisseurs',
      'documents',
      'label_prints'
    ])
  LOOP
    -- Ensure owner_id exists and is NOT NULL
    BEGIN
      -- Check if owner_id column exists
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = table_name 
        AND column_name = 'owner_id'
      ) THEN
        -- Add owner_id column
        EXECUTE format('ALTER TABLE public.%I ADD COLUMN owner_id UUID DEFAULT auth.uid()', table_name);
        
        -- Migrate from user_id if it exists
        IF EXISTS (
          SELECT 1 FROM information_schema.columns 
          WHERE table_schema = 'public' 
          AND table_name = table_name 
          AND column_name = 'user_id'
        ) THEN
          EXECUTE format('UPDATE public.%I SET owner_id = user_id WHERE owner_id IS NULL AND user_id IS NOT NULL', table_name);
        END IF;
        
        -- Migrate from created_by if it exists
        IF EXISTS (
          SELECT 1 FROM information_schema.columns 
          WHERE table_schema = 'public' 
          AND table_name = table_name 
          AND column_name = 'created_by'
        ) THEN
          EXECUTE format('UPDATE public.%I SET owner_id = created_by WHERE owner_id IS NULL AND created_by IS NOT NULL', table_name);
        END IF;
        
        -- Assign NULL values to first user if any exist
        IF first_user_id IS NOT NULL THEN
          EXECUTE format('SELECT COUNT(*) FROM public.%I WHERE owner_id IS NULL', table_name) INTO null_count;
          IF null_count > 0 THEN
            EXECUTE format('UPDATE public.%I SET owner_id = $1 WHERE owner_id IS NULL', table_name) USING first_user_id;
          END IF;
        END IF;
        
        -- Set NOT NULL constraint
        EXECUTE format('ALTER TABLE public.%I ALTER COLUMN owner_id SET NOT NULL', table_name);
        EXECUTE format('ALTER TABLE public.%I ALTER COLUMN owner_id SET DEFAULT auth.uid()', table_name);
      ELSE
        -- Column exists, ensure it's NOT NULL and has default
        EXECUTE format('ALTER TABLE public.%I ALTER COLUMN owner_id SET DEFAULT auth.uid()', table_name);
        
        -- Fix NULL values if any
        IF first_user_id IS NOT NULL THEN
          EXECUTE format('SELECT COUNT(*) FROM public.%I WHERE owner_id IS NULL', table_name) INTO null_count;
          IF null_count > 0 THEN
            EXECUTE format('UPDATE public.%I SET owner_id = $1 WHERE owner_id IS NULL', table_name) USING first_user_id;
          END IF;
        END IF;
        
        -- Try to set NOT NULL (may fail if there are still NULLs, which is OK for taches_nettoyage)
        BEGIN
          EXECUTE format('ALTER TABLE public.%I ALTER COLUMN owner_id SET NOT NULL', table_name);
        EXCEPTION WHEN OTHERS THEN
          -- OK for taches_nettoyage which allows NULL for system templates
          NULL;
        END;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Warning: Could not set owner_id for %: %', table_name, SQLERRM;
    END;
  END LOOP;
  
  -- Special handling for taches_nettoyage (allows NULL for system templates)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'taches_nettoyage' 
    AND column_name = 'owner_id'
  ) THEN
    -- Ensure it has default but allow NULL
    ALTER TABLE public.taches_nettoyage ALTER COLUMN owner_id DROP NOT NULL;
    ALTER TABLE public.taches_nettoyage ALTER COLUMN owner_id SET DEFAULT auth.uid();
  END IF;
END $$;

-- ============================================
-- STEP 2: ENABLE RLS ON ALL TABLES
-- ============================================
-- Note: All indexes are created in 00_schema.sql (duplicate index creation removed)

ALTER TABLE public.appareils ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.temperatures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nettoyages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.taches_nettoyage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fournisseurs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friteuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oil_changes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.produits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.label_prints ENABLE ROW LEVEL SECURITY;

-- ============================================
-- STEP 3: DROP ALL EXISTING POLICIES
-- ============================================
-- This ensures we start with a clean slate

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN (
        'produits', 'friteuses', 'oil_changes', 'temperatures',
        'appareils', 'nettoyages', 'taches_nettoyage', 'receptions',
        'fournisseurs', 'documents', 'label_prints'
      )
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;

-- ============================================
-- STEP 4: CREATE STRICT RLS POLICIES
-- ============================================
-- All policies use owner_id for strict user isolation

-- PRODUITS: User can only access their own products
CREATE POLICY "produits_select_policy" ON public.produits
  FOR SELECT TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY "produits_insert_policy" ON public.produits
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "produits_update_policy" ON public.produits
  FOR UPDATE TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "produits_delete_policy" ON public.produits
  FOR DELETE TO authenticated
  USING (owner_id = auth.uid());

-- FRITEUSES: User can only access their own fryers
CREATE POLICY "friteuses_select_policy" ON public.friteuses
  FOR SELECT TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY "friteuses_insert_policy" ON public.friteuses
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "friteuses_update_policy" ON public.friteuses
  FOR UPDATE TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "friteuses_delete_policy" ON public.friteuses
  FOR DELETE TO authenticated
  USING (owner_id = auth.uid());

-- OIL_CHANGES: User can only access their own oil change records
CREATE POLICY "oil_changes_select_policy" ON public.oil_changes
  FOR SELECT TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY "oil_changes_insert_policy" ON public.oil_changes
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "oil_changes_update_policy" ON public.oil_changes
  FOR UPDATE TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "oil_changes_delete_policy" ON public.oil_changes
  FOR DELETE TO authenticated
  USING (owner_id = auth.uid());

-- TEMPERATURES: User can only access their own temperature readings
CREATE POLICY "temperatures_select_policy" ON public.temperatures
  FOR SELECT TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY "temperatures_insert_policy" ON public.temperatures
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "temperatures_update_policy" ON public.temperatures
  FOR UPDATE TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "temperatures_delete_policy" ON public.temperatures
  FOR DELETE TO authenticated
  USING (owner_id = auth.uid());

-- APPAREILS: User can only access their own devices
CREATE POLICY "appareils_select_policy" ON public.appareils
  FOR SELECT TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY "appareils_insert_policy" ON public.appareils
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "appareils_update_policy" ON public.appareils
  FOR UPDATE TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "appareils_delete_policy" ON public.appareils
  FOR DELETE TO authenticated
  USING (owner_id = auth.uid());

-- NETTOYAGES: User can only access their own cleaning records
CREATE POLICY "nettoyages_select_policy" ON public.nettoyages
  FOR SELECT TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY "nettoyages_insert_policy" ON public.nettoyages
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "nettoyages_update_policy" ON public.nettoyages
  FOR UPDATE TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "nettoyages_delete_policy" ON public.nettoyages
  FOR DELETE TO authenticated
  USING (owner_id = auth.uid());

-- TACHES_NETTOYAGE: Special handling for shared templates
-- Users can see system templates (owner_id IS NULL) and their own tasks
CREATE POLICY "taches_nettoyage_select_policy" ON public.taches_nettoyage
  FOR SELECT TO authenticated
  USING (owner_id = auth.uid() OR owner_id IS NULL);

CREATE POLICY "taches_nettoyage_insert_policy" ON public.taches_nettoyage
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "taches_nettoyage_update_policy" ON public.taches_nettoyage
  FOR UPDATE TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "taches_nettoyage_delete_policy" ON public.taches_nettoyage
  FOR DELETE TO authenticated
  USING (owner_id = auth.uid());

-- RECEPTIONS: User can only access their own reception records
CREATE POLICY "receptions_select_policy" ON public.receptions
  FOR SELECT TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY "receptions_insert_policy" ON public.receptions
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "receptions_update_policy" ON public.receptions
  FOR UPDATE TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "receptions_delete_policy" ON public.receptions
  FOR DELETE TO authenticated
  USING (owner_id = auth.uid());

-- FOURNISSEURS: User can only access their own suppliers
CREATE POLICY "fournisseurs_select_policy" ON public.fournisseurs
  FOR SELECT TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY "fournisseurs_insert_policy" ON public.fournisseurs
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "fournisseurs_update_policy" ON public.fournisseurs
  FOR UPDATE TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "fournisseurs_delete_policy" ON public.fournisseurs
  FOR DELETE TO authenticated
  USING (owner_id = auth.uid());

-- DOCUMENTS: User can only access their own documents
CREATE POLICY "documents_select_policy" ON public.documents
  FOR SELECT TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY "documents_insert_policy" ON public.documents
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "documents_update_policy" ON public.documents
  FOR UPDATE TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "documents_delete_policy" ON public.documents
  FOR DELETE TO authenticated
  USING (owner_id = auth.uid());

-- LABEL_PRINTS: User can only access their own label print history
CREATE POLICY "label_prints_select_policy" ON public.label_prints
  FOR SELECT TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY "label_prints_insert_policy" ON public.label_prints
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "label_prints_update_policy" ON public.label_prints
  FOR UPDATE TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "label_prints_delete_policy" ON public.label_prints
  FOR DELETE TO authenticated
  USING (owner_id = auth.uid());

COMMIT;

-- ============================================
-- VERIFICATION
-- ============================================
-- Uncomment to verify RLS is enabled and policies exist

/*
SELECT 
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'produits', 'friteuses', 'oil_changes', 'temperatures',
    'appareils', 'nettoyages', 'taches_nettoyage', 'receptions',
    'fournisseurs', 'documents', 'label_prints'
  )
ORDER BY tablename;

SELECT 
  tablename,
  COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'produits', 'friteuses', 'oil_changes', 'temperatures',
    'appareils', 'nettoyages', 'taches_nettoyage', 'receptions',
    'fournisseurs', 'documents', 'label_prints'
  )
GROUP BY tablename
ORDER BY tablename;
*/

-- ============================================
-- END OF SECURITY POLICIES
-- ============================================

