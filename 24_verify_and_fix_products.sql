-- ============================================
-- VERIFY AND FIX: Products owner_id issue
-- ============================================
-- This script verifies which products belong to which user
-- and fixes the owner_id if needed
-- ============================================

-- 1. Show ALL products with their owners
SELECT 
  p.id,
  p.nom,
  p.owner_id,
  u.email as owner_email,
  p.supplier_id,
  s.nom as supplier_name,
  p.type_produit,
  p.actif
FROM public.produits p
LEFT JOIN auth.users u ON u.id = p.owner_id
LEFT JOIN public.suppliers s ON s.id = p.supplier_id
ORDER BY p.created_at DESC;

-- 2. Count products per user
SELECT 
  u.email,
  u.id as user_id,
  COUNT(p.id) as product_count,
  COUNT(CASE WHEN p.supplier_id IS NOT NULL THEN 1 END) as supplier_products,
  COUNT(CASE WHEN p.supplier_id IS NULL THEN 1 END) as internal_products
FROM auth.users u
LEFT JOIN public.produits p ON p.owner_id = u.id
GROUP BY u.id, u.email
ORDER BY product_count DESC;

-- 3. Check products for "100% Crousty Sevran" organization
SELECT 
  o.name as organization_name,
  u.email as user_email,
  COUNT(p.id) as total_products
FROM public.organizations o
JOIN auth.users u ON u.id = o.id
LEFT JOIN public.produits p ON p.owner_id = u.id
WHERE o.name = '100% Crousty Sevran'
GROUP BY o.name, u.email;

-- 4. Show products that should belong to "100% Crousty Sevran"
SELECT 
  p.nom,
  p.owner_id,
  u.email as current_owner_email,
  o.name as organization_name
FROM public.produits p
JOIN auth.users u ON u.id = p.owner_id
JOIN public.organizations o ON o.id = u.id
WHERE o.name = '100% Crousty Sevran'
ORDER BY p.nom
LIMIT 20;

-- 5. FIX: Transfer all products to correct user
-- IMPORTANT: Replace 'adlaniasma@gmail.com' with the correct email
DO $$
DECLARE
  v_target_user_id UUID;
  v_target_email TEXT := 'adlaniasma@gmail.com';
  v_product_count INTEGER;
BEGIN
  -- Get target user ID
  SELECT id INTO v_target_user_id 
  FROM auth.users 
  WHERE email = v_target_email;
  
  IF v_target_user_id IS NULL THEN
    RAISE EXCEPTION 'User with email % not found!', v_target_email;
  END IF;
  
  RAISE NOTICE 'Target user ID: %', v_target_user_id::text;
  
  -- Count products that need to be fixed
  SELECT COUNT(*) INTO v_product_count
  FROM public.produits
  WHERE owner_id != v_target_user_id;
  
  RAISE NOTICE 'Found % products with wrong owner_id', v_product_count;
  
  -- Transfer ALL products to correct owner
  UPDATE public.produits
  SET owner_id = v_target_user_id
  WHERE owner_id != v_target_user_id;
  
  RAISE NOTICE '✅ Transferred % products to user %', v_product_count, v_target_email;
  
  -- Verify
  SELECT COUNT(*) INTO v_product_count
  FROM public.produits
  WHERE owner_id = v_target_user_id;
  
  RAISE NOTICE '✅ Verification: User % now owns % products', v_target_email, v_product_count;
END $$;

-- 6. Final verification: Show all products for the target user
SELECT 
  COUNT(*) as total_products,
  COUNT(CASE WHEN supplier_id IS NOT NULL THEN 1 END) as supplier_products,
  COUNT(CASE WHEN supplier_id IS NULL THEN 1 END) as internal_products
FROM public.produits
WHERE owner_id = (SELECT id FROM auth.users WHERE email = 'adlaniasma@gmail.com');











