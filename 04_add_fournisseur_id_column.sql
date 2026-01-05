-- ============================================
-- ADD fournisseur_id COLUMN TO RECEPTIONS
-- ============================================
-- This script adds the fournisseur_id column for compatibility
-- ============================================

-- Add fournisseur_id column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receptions' AND column_name = 'fournisseur_id'
  ) THEN
    ALTER TABLE public.receptions 
    ADD COLUMN fournisseur_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL;
    
    -- Create index for better performance
    CREATE INDEX IF NOT EXISTS idx_receptions_fournisseur_id 
    ON public.receptions(fournisseur_id);
  END IF;
END $$;

-- Also ensure supplier_id exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receptions' AND column_name = 'supplier_id'
  ) THEN
    ALTER TABLE public.receptions 
    ADD COLUMN supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL;
    
    -- Create index for better performance
    CREATE INDEX IF NOT EXISTS idx_receptions_supplier_id 
    ON public.receptions(supplier_id);
  END IF;
END $$;



