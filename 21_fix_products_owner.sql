-- ============================================
-- FIX: Transfer products to current user
-- ============================================
-- This script transfers products from one user to another
-- ============================================
-- IMPORTANT: Replace 'adlaniasma@gmail.com' with the email
-- of the user who should own the products
-- ============================================

DO $$
DECLARE
  v_source_user_id UUID;
  v_target_user_id UUID;
  v_target_email TEXT := 'adlaniasma@gmail.com'; -- CHANGE THIS to the email of the user who should see the products
  v_product_count INTEGER;
BEGIN
  -- Get the target user ID (the user who should own the products)
  SELECT id INTO v_target_user_id 
  FROM auth.users 
  WHERE email = v_target_email;
  
  IF v_target_user_id IS NULL THEN
    RAISE EXCEPTION 'Target user with email % not found!', v_target_email;
  END IF;
  
  RAISE NOTICE 'Target user ID: %', v_target_user_id::text;
  
  -- Count products that need to be transferred
  SELECT COUNT(*) INTO v_product_count
  FROM public.produits
  WHERE owner_id != v_target_user_id;
  
  RAISE NOTICE 'Found % products that need to be transferred', v_product_count;
  
  -- Transfer all products to the target user
  UPDATE public.produits
  SET owner_id = v_target_user_id
  WHERE owner_id != v_target_user_id;
  
  RAISE NOTICE '✅ Transferred % products to user % (%)', v_product_count, v_target_email, v_target_user_id::text;
  
  -- Verify the transfer
  SELECT COUNT(*) INTO v_product_count
  FROM public.produits
  WHERE owner_id = v_target_user_id;
  
  RAISE NOTICE '✅ Verification: User % now owns % products', v_target_email, v_product_count;
END $$;

-- Verify: Show products for the target user
SELECT 
  u.email,
  COUNT(p.id) as product_count,
  COUNT(DISTINCT p.categorie) as categories
FROM auth.users u
LEFT JOIN public.produits p ON p.owner_id = u.id
WHERE u.email = 'adlaniasma@gmail.com'
GROUP BY u.email;











