-- ============================================
-- ADD EMPLOYEE NAMES TO ACTION TABLES
-- ============================================
-- This migration adds employee first_name and last_name columns
-- to temperatures, receptions, nettoyages, and oil_changes tables
-- to track which employee performed each action
-- ============================================

BEGIN;

-- ============================================
-- 1. TEMPERATURES
-- ============================================
DO $$
BEGIN
  -- Add employee_first_name column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'temperatures' AND column_name = 'employee_first_name'
  ) THEN
    ALTER TABLE public.temperatures 
    ADD COLUMN employee_first_name TEXT;
  END IF;

  -- Add employee_last_name column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'temperatures' AND column_name = 'employee_last_name'
  ) THEN
    ALTER TABLE public.temperatures 
    ADD COLUMN employee_last_name TEXT;
  END IF;
END $$;

-- ============================================
-- 2. RECEPTIONS
-- ============================================
DO $$
BEGIN
  -- Add employee_first_name column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receptions' AND column_name = 'employee_first_name'
  ) THEN
    ALTER TABLE public.receptions 
    ADD COLUMN employee_first_name TEXT;
  END IF;

  -- Add employee_last_name column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receptions' AND column_name = 'employee_last_name'
  ) THEN
    ALTER TABLE public.receptions 
    ADD COLUMN employee_last_name TEXT;
  END IF;
END $$;

-- ============================================
-- 3. NETTOYAGES
-- ============================================
DO $$
BEGIN
  -- Add employee_first_name column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'nettoyages' AND column_name = 'employee_first_name'
  ) THEN
    ALTER TABLE public.nettoyages 
    ADD COLUMN employee_first_name TEXT;
  END IF;

  -- Add employee_last_name column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'nettoyages' AND column_name = 'employee_last_name'
  ) THEN
    ALTER TABLE public.nettoyages 
    ADD COLUMN employee_last_name TEXT;
  END IF;
END $$;

-- ============================================
-- 4. OIL_CHANGES
-- ============================================
DO $$
BEGIN
  -- Add employee_first_name column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'oil_changes' AND column_name = 'employee_first_name'
  ) THEN
    ALTER TABLE public.oil_changes 
    ADD COLUMN employee_first_name TEXT;
  END IF;

  -- Add employee_last_name column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'oil_changes' AND column_name = 'employee_last_name'
  ) THEN
    ALTER TABLE public.oil_changes 
    ADD COLUMN employee_last_name TEXT;
  END IF;
END $$;

-- ============================================
-- INDEXES (optional, for performance)
-- ============================================
CREATE INDEX IF NOT EXISTS idx_temperatures_employee_name 
  ON public.temperatures(employee_first_name, employee_last_name);

CREATE INDEX IF NOT EXISTS idx_receptions_employee_name 
  ON public.receptions(employee_first_name, employee_last_name);

CREATE INDEX IF NOT EXISTS idx_nettoyages_employee_name 
  ON public.nettoyages(employee_first_name, employee_last_name);

CREATE INDEX IF NOT EXISTS idx_oil_changes_employee_name 
  ON public.oil_changes(employee_first_name, employee_last_name);

COMMIT;

-- ============================================
-- VERIFICATION QUERIES (optional - run manually)
-- ============================================
-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'temperatures' 
-- AND column_name LIKE 'employee%';
--
-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'receptions' 
-- AND column_name LIKE 'employee%';
--
-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'nettoyages' 
-- AND column_name LIKE 'employee%';
--
-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'oil_changes' 
-- AND column_name LIKE 'employee%';

