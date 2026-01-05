-- ============================================
-- ADDITIVE SCHEMA CHANGES FOR REFONTE - SAFE VERSION
-- ============================================
-- This script is safe to run multiple times
-- It drops existing objects before creating them
-- Execute after 00_schema.sql
-- ============================================

-- ============================================
-- ORGANIZATIONS (Multi-tenant support)
-- ============================================
-- Drop table if exists and recreate (only if you want to reset)
-- Otherwise, just create if not exists
CREATE TABLE IF NOT EXISTS public.organizations (
  id UUID PRIMARY KEY, -- Use user.id as primary key for simplicity
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- EMPLOYEES (Non-admin users, linked to organization)
-- ============================================
CREATE TABLE IF NOT EXISTS public.employees (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  role TEXT NOT NULL, -- 'manager', 'cook', 'cleaner', etc.
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- ============================================
-- SUPPLIERS
-- ============================================
CREATE TABLE IF NOT EXISTS public.suppliers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  contact_info TEXT,
  is_occasional BOOLEAN DEFAULT FALSE, -- TRUE for quick-add suppliers
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  owner_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE
);

-- ============================================
-- SUPPLIER_PRODUCTS (Junction: Products ↔ Suppliers)
-- ============================================
CREATE TABLE IF NOT EXISTS public.supplier_products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  supplier_id UUID NOT NULL REFERENCES public.suppliers(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.produits(id) ON DELETE CASCADE,
  default_lot_number TEXT,
  default_dluo_days INTEGER, -- Days before DLUO expiration
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(supplier_id, product_id)
);

-- ============================================
-- ENHANCE RECEPTIONS (Add non-conformity link, fixed time)
-- ============================================
-- Add columns if they don't exist
DO $$
BEGIN
  -- Fixed reception time (10:00)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receptions' AND column_name = 'reception_time'
  ) THEN
    ALTER TABLE public.receptions ADD COLUMN reception_time TIME DEFAULT '10:00:00';
  END IF;
  
  -- Non-conformity link
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receptions' AND column_name = 'non_conformity_id'
  ) THEN
    ALTER TABLE public.receptions ADD COLUMN non_conformity_id UUID;
  END IF;
  
  -- Employee who performed reception
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receptions' AND column_name = 'performed_by_employee_id'
  ) THEN
    ALTER TABLE public.receptions ADD COLUMN performed_by_employee_id UUID REFERENCES public.employees(id) ON DELETE SET NULL;
  END IF;
  
  -- Supplier link (new column)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receptions' AND column_name = 'supplier_id'
  ) THEN
    ALTER TABLE public.receptions ADD COLUMN supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Add foreign key constraint for receptions.non_conformity_id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'receptions_non_conformity_id_fkey'
  ) THEN
    ALTER TABLE public.receptions 
    ADD CONSTRAINT receptions_non_conformity_id_fkey 
    FOREIGN KEY (non_conformity_id) REFERENCES public.non_conformities(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ============================================
-- NON_CONFORMITIES (Refusal declarations)
-- ============================================
CREATE TABLE IF NOT EXISTS public.non_conformities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reception_id UUID REFERENCES public.receptions(id) ON DELETE CASCADE,
  -- 4 refusal criteria
  temperature_non_compliant BOOLEAN DEFAULT FALSE, -- >6-7°C fresh OR >-18°C frozen
  packaging_opened BOOLEAN DEFAULT FALSE, -- Opened carton
  packaging_wet BOOLEAN DEFAULT FALSE, -- Wet carton
  label_missing BOOLEAN DEFAULT FALSE, -- Missing label on carton
  -- Details
  declaration_text TEXT, -- Free text declaration
  photo_urls TEXT[], -- Array of photo URLs
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  performed_by_employee_id UUID REFERENCES public.employees(id) ON DELETE SET NULL
);

-- ============================================
-- ENHANCE CLEANING_TASKS (Employee assignment, enabled flag)
-- ============================================
DO $$
BEGIN
  -- Enabled flag
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'taches_nettoyage' AND column_name = 'enabled'
  ) THEN
    ALTER TABLE public.taches_nettoyage ADD COLUMN enabled BOOLEAN DEFAULT TRUE;
  END IF;
  
  -- Assigned employee
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'taches_nettoyage' AND column_name = 'assigned_employee_id'
  ) THEN
    ALTER TABLE public.taches_nettoyage ADD COLUMN assigned_employee_id UUID REFERENCES public.employees(id) ON DELETE SET NULL;
  END IF;
  
  -- Notification time (for future local notifications)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'taches_nettoyage' AND column_name = 'notification_minutes_before'
  ) THEN
    ALTER TABLE public.taches_nettoyage ADD COLUMN notification_minutes_before INTEGER DEFAULT 0;
  END IF;
END $$;

-- ============================================
-- CLEANING_TASK_RUNS (Completion records with employee tracking)
-- ============================================
CREATE TABLE IF NOT EXISTS public.cleaning_task_runs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  task_id UUID NOT NULL REFERENCES public.taches_nettoyage(id) ON DELETE CASCADE,
  scheduled_date DATE NOT NULL, -- The date the task was due
  completed_at TIMESTAMPTZ, -- When it was marked done
  performed_by_employee_id UUID REFERENCES public.employees(id) ON DELETE SET NULL,
  done_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Admin who marked it
  notes TEXT,
  photo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(task_id, scheduled_date)
);

-- ============================================
-- ENHANCE OIL_CHANGES (Employee tracking)
-- ============================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'oil_changes' AND column_name = 'performed_by_employee_id'
  ) THEN
    ALTER TABLE public.oil_changes ADD COLUMN performed_by_employee_id UUID REFERENCES public.employees(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ============================================
-- AUDIT_LOG (Central history with traceability)
-- ============================================
CREATE TABLE IF NOT EXISTS public.audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  operation_type TEXT NOT NULL, -- 'reception', 'temperature', 'oil_change', 'cleaning', 'non_conformity'
  operation_id UUID, -- ID of the related record
  action TEXT NOT NULL, -- 'create', 'update', 'delete', 'complete'
  actor_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Admin who performed action
  actor_employee_id UUID REFERENCES public.employees(id) ON DELETE SET NULL, -- Employee if action was assigned
  description TEXT, -- Human-readable description
  metadata JSONB, -- Additional context (temperature value, product name, etc.)
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- INDEXES for performance
-- ============================================
CREATE INDEX IF NOT EXISTS idx_employees_organization ON public.employees(organization_id);
CREATE INDEX IF NOT EXISTS idx_employees_created_by ON public.employees(created_by);
CREATE INDEX IF NOT EXISTS idx_suppliers_organization ON public.suppliers(organization_id);
CREATE INDEX IF NOT EXISTS idx_suppliers_owner ON public.suppliers(owner_id);
CREATE INDEX IF NOT EXISTS idx_supplier_products_supplier ON public.supplier_products(supplier_id);
CREATE INDEX IF NOT EXISTS idx_supplier_products_product ON public.supplier_products(product_id);
CREATE INDEX IF NOT EXISTS idx_non_conformities_reception ON public.non_conformities(reception_id);
CREATE INDEX IF NOT EXISTS idx_cleaning_task_runs_task ON public.cleaning_task_runs(task_id);
CREATE INDEX IF NOT EXISTS idx_cleaning_task_runs_date ON public.cleaning_task_runs(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_audit_log_organization ON public.audit_log(organization_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_type ON public.audit_log(operation_type);
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON public.audit_log(created_at DESC);

-- ============================================
-- TRIGGERS for updated_at (Safe version - drops first)
-- ============================================
-- Create or replace the function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop existing triggers if they exist, then create them
DROP TRIGGER IF EXISTS update_organizations_updated_at ON public.organizations;
CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON public.organizations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_employees_updated_at ON public.employees;
CREATE TRIGGER update_employees_updated_at BEFORE UPDATE ON public.employees
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_suppliers_updated_at ON public.suppliers;
CREATE TRIGGER update_suppliers_updated_at BEFORE UPDATE ON public.suppliers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();



