-- ============================================
-- CREATE EMPLOYEE "Lea Dupont" AS SERVEUR
-- ============================================
-- This script creates an employee "Lea Dupont" 
-- with role "serveur" for organization "100% Crousty Sevran"
-- ============================================

DO $$
DECLARE
  v_user_id UUID;
  v_org_id UUID;
  v_employee_id UUID;
BEGIN
  -- Get user ID for adlaniasma@gmail.com
  SELECT id INTO v_user_id FROM auth.users WHERE email = 'adlaniasma@gmail.com';
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User adlaniasma@gmail.com not found! Please create the user account first.';
  END IF;
  
  RAISE NOTICE 'Using user_id: %', v_user_id::text;
  
  -- CRITICAL: Organization ID = User ID (for proper RLS)
  -- Get organization ID for "100% Crousty Sevran" - it should have id = user_id
  SELECT id INTO v_org_id FROM public.organizations WHERE id = v_user_id;
  
  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'Organization for user adlaniasma@gmail.com not found! Please run 16_create_crousty_organization.sql first.';
  END IF;
  
  RAISE NOTICE 'Using organization_id: %', v_org_id::text;
  
  -- Check if employee already exists
  SELECT id INTO v_employee_id
  FROM public.employees
  WHERE organization_id = v_org_id
    AND first_name = 'Lea'
    AND last_name = 'Dupont';
  
  IF v_employee_id IS NOT NULL THEN
    RAISE NOTICE 'Employee "Lea Dupont" already exists with ID: %', v_employee_id::text;
    RAISE NOTICE 'Skipping creation.';
  ELSE
    -- Create employee "Lea Dupont" as serveur (not admin)
    INSERT INTO public.employees (
      organization_id,
      first_name,
      last_name,
      role,
      is_active,
      is_admin,
      created_by,
      created_at,
      updated_at
    )
    VALUES (
      v_org_id,
      'Lea',
      'Dupont',
      'serveur',
      true,
      false,
      v_user_id,
      NOW(),
      NOW()
    )
    RETURNING id INTO v_employee_id;
    
    RAISE NOTICE '✅ Employee "Lea Dupont" created successfully with ID: %', v_employee_id::text;
  END IF;
END $$;

-- Verify the creation
SELECT 
  e.id as employee_id,
  e.first_name,
  e.last_name,
  e.role,
  e.is_active,
  e.is_admin,
  o.name as organization_name,
  e.created_at
FROM public.employees e
JOIN public.organizations o ON o.id = e.organization_id
WHERE e.first_name = 'Lea'
  AND e.last_name = 'Dupont'
  AND o.name = '100% Crousty Sevran';

