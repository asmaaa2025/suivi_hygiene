-- ============================================
-- ADD ADMIN FIELDS TO EMPLOYEES TABLE
-- ============================================
-- Adds is_admin, admin_code, and admin_email columns to employees table
-- ============================================

-- Add is_admin column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'employees' AND column_name = 'is_admin'
  ) THEN
    ALTER TABLE public.employees
    ADD COLUMN is_admin BOOLEAN DEFAULT FALSE;
    
    -- Create index for better performance
    CREATE INDEX IF NOT EXISTS idx_employees_is_admin
    ON public.employees(is_admin);
  END IF;
END $$;

-- Add admin_code column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'employees' AND column_name = 'admin_code'
  ) THEN
    ALTER TABLE public.employees
    ADD COLUMN admin_code TEXT;
    
    -- Add constraint to ensure admin_code is 4 digits when provided
    ALTER TABLE public.employees
    ADD CONSTRAINT employees_admin_code_check
    CHECK (admin_code IS NULL OR (LENGTH(admin_code) = 4 AND admin_code ~ '^[0-9]{4}$'));
  END IF;
END $$;

-- Add admin_email column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'employees' AND column_name = 'admin_email'
  ) THEN
    ALTER TABLE public.employees
    ADD COLUMN admin_email TEXT;
  END IF;
END $$;

-- Add constraint: if is_admin is true, admin_code and admin_email must be provided
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'employees_admin_required_fields'
  ) THEN
    ALTER TABLE public.employees
    ADD CONSTRAINT employees_admin_required_fields
    CHECK (
      (is_admin = FALSE) OR 
      (is_admin = TRUE AND admin_code IS NOT NULL AND admin_email IS NOT NULL)
    );
  END IF;
END $$;

