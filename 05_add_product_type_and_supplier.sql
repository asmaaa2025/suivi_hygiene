-- ============================================
-- ADD TYPE_PRODUIT AND SUPPLIER_ID TO PRODUITS
-- ============================================
-- This script adds product type and supplier link columns
-- ============================================

-- Add type_produit column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'produits' AND column_name = 'type_produit'
  ) THEN
    ALTER TABLE public.produits 
    ADD COLUMN type_produit TEXT;
    
    -- Add check constraint for valid types
    ALTER TABLE public.produits
    ADD CONSTRAINT produits_type_produit_check 
    CHECK (type_produit IS NULL OR type_produit IN ('reçu', 'fini', 'transformé', 'autre'));
  END IF;
END $$;

-- Add supplier_id column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'produits' AND column_name = 'supplier_id'
  ) THEN
    ALTER TABLE public.produits 
    ADD COLUMN supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL;
    
    -- Create index for better performance
    CREATE INDEX IF NOT EXISTS idx_produits_supplier_id 
    ON public.produits(supplier_id);
  END IF;
END $$;

