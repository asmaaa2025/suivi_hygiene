-- ============================================
-- SEED DATA (OPTIONAL)
-- ============================================
-- This file contains optional seed/test data
-- Execute this AFTER 00_schema.sql and 10_security.sql
-- Only run this in development/test environments
-- ============================================

-- ============================================
-- SEED DATA: Appareils (Test Devices)
-- ============================================
-- Insert sample devices (only if table is empty or for testing)
-- Note: These will be owned by the first user in auth.users

DO $$
DECLARE
  first_user_id UUID;
BEGIN
  -- Get first user
  SELECT id INTO first_user_id FROM auth.users ORDER BY created_at LIMIT 1;
  
  IF first_user_id IS NOT NULL THEN
    -- Insert test devices only if none exist
    IF NOT EXISTS (SELECT 1 FROM public.appareils LIMIT 1) THEN
      INSERT INTO public.appareils (nom, type_appareil, seuil_min, seuil_max, description, owner_id) VALUES
        ('Frigo', 'frigo', 2.0, 4.0, 'Réfrigérateur principal', first_user_id),
        ('Congélateur', 'congelateur', -25.0, -18.0, 'Congélateur principal', first_user_id),
        ('Vitrine', 'vitrine', 2.0, 8.0, 'Vitrine réfrigérée', first_user_id),
        ('Friteuse 1', 'friteuse', 160.00, 200.00, 'Friteuse principale', first_user_id)
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;
END $$;

-- ============================================
-- END OF SEED DATA
-- ============================================
-- Remove or comment out the above section in production
-- ============================================

