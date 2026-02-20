-- ============================================
-- DIAGNOSTIC: Why products are not showing
-- ============================================
-- This script helps diagnose why products are not visible
-- ============================================

-- 1. Check all users and their IDs
SELECT 
  id as user_id,
  email,
  created_at
FROM auth.users
ORDER BY created_at DESC;

-- 2. Check all products and their owner_id
SELECT 
  p.id,
  p.nom,
  p.owner_id,
  u.email as owner_email,
  p.supplier_id,
  s.nom as supplier_name,
  p.created_at
FROM public.produits p
LEFT JOIN auth.users u ON u.id = p.owner_id
LEFT JOIN public.suppliers s ON s.id = p.supplier_id
ORDER BY p.created_at DESC
LIMIT 50;

-- 3. Count products per user
SELECT 
  u.email,
  u.id as user_id,
  COUNT(p.id) as product_count
FROM auth.users u
LEFT JOIN public.produits p ON p.owner_id = u.id
GROUP BY u.id, u.email
ORDER BY product_count DESC;

-- 4. Check products for specific user (adlaniasma@gmail.com)
SELECT 
  COUNT(*) as total_products,
  COUNT(DISTINCT categorie) as categories
FROM public.produits p
JOIN auth.users u ON u.id = p.owner_id
WHERE u.email = 'adlaniasma@gmail.com';

-- 5. Show products for adlaniasma@gmail.com
SELECT 
  p.nom,
  p.categorie,
  p.owner_id,
  u.email as owner_email
FROM public.produits p
JOIN auth.users u ON u.id = p.owner_id
WHERE u.email = 'adlaniasma@gmail.com'
ORDER BY p.nom
LIMIT 20;

-- 6. Check RLS policies on produits table
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'produits';











