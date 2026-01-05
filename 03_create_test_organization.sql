-- ============================================
-- CREATE TEST ORGANIZATION
-- ============================================
-- This script creates an organization for testing
-- Replace 'YOUR_USER_ID_HERE' with your actual user ID from auth.users
-- ============================================

-- First, check if RLS is enabled
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

-- Check if organizations table exists and has the right structure
-- If not, run 01_schema_additions.sql first

-- To find your user ID, run this query:
-- SELECT id, email FROM auth.users;

-- Then create an organization manually (replace YOUR_USER_ID_HERE):
-- INSERT INTO public.organizations (id, name)
-- VALUES ('YOUR_USER_ID_HERE', 'Mon Organisation')
-- ON CONFLICT (id) DO NOTHING;

-- Or create organization for all existing users:
DO $$
DECLARE
  user_record RECORD;
BEGIN
  FOR user_record IN SELECT id, email FROM auth.users LOOP
    INSERT INTO public.organizations (id, name)
    VALUES (user_record.id, 'Organisation ' || COALESCE(user_record.email, user_record.id::text))
    ON CONFLICT (id) DO NOTHING;
  END LOOP;
END $$;

-- Verify organizations were created
SELECT id, name, created_at FROM public.organizations;



