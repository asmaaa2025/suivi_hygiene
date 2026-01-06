-- ============================================
-- CLOCK SESSIONS AND HR SCHEMA
-- ============================================
-- This file adds tables for clock-in/out, personnel registry, and HACCP actions
-- Execute after 00_schema.sql and 06_add_employee_admin_fields.sql
-- ============================================

-- ============================================
-- 1. CLOCK_SESSIONS (Clock-in/Clock-out sessions)
-- ============================================
CREATE TABLE IF NOT EXISTS public.clock_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE, -- References employee.id (for shared tablet scenario)
  start_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  end_at TIMESTAMPTZ,
  device_id TEXT, -- Optional device identifier
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for clock_sessions
CREATE INDEX IF NOT EXISTS idx_clock_sessions_user_id ON public.clock_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_clock_sessions_start_at ON public.clock_sessions(start_at);
CREATE INDEX IF NOT EXISTS idx_clock_sessions_user_open ON public.clock_sessions(user_id, end_at) WHERE end_at IS NULL;

-- ============================================
-- 2. PERSONNEL (HR Registry - Admin only)
-- ============================================
CREATE TABLE IF NOT EXISTS public.personnel (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE, -- NULL = active, set date = inactive
  contract_type TEXT NOT NULL CHECK (contract_type IN ('CDI', 'CDD', 'Alternance', 'Intérim', 'Extra', 'Stagiaire', 'Autre')),
  is_foreign_worker BOOLEAN DEFAULT FALSE,
  foreign_work_permit_type TEXT, -- Required if is_foreign_worker = true
  foreign_work_permit_number TEXT, -- Required if is_foreign_worker = true
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Optional link to user account
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  -- Constraint: foreign worker must have permit info
  CONSTRAINT personnel_foreign_worker_check CHECK (
    (is_foreign_worker = FALSE) OR 
    (is_foreign_worker = TRUE AND foreign_work_permit_type IS NOT NULL AND foreign_work_permit_number IS NOT NULL)
  ),
  -- Constraint: end_date must be after start_date
  CONSTRAINT personnel_dates_check CHECK (
    end_date IS NULL OR end_date >= start_date
  )
);

-- Indexes for personnel
CREATE INDEX IF NOT EXISTS idx_personnel_user_id ON public.personnel(user_id);
CREATE INDEX IF NOT EXISTS idx_personnel_start_date ON public.personnel(start_date);
CREATE INDEX IF NOT EXISTS idx_personnel_active ON public.personnel(end_date) WHERE end_date IS NULL;

-- ============================================
-- 3. HACCP_ACTIONS (HACCP action tracking)
-- ============================================
CREATE TABLE IF NOT EXISTS public.haccp_actions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('temperature', 'reception', 'cleaning', 'corrective_action', 'doc_upload', 'oil_change', 'other')),
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  payload_json JSONB NOT NULL DEFAULT '{}'::jsonb, -- Flexible payload for different action types
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for haccp_actions
CREATE INDEX IF NOT EXISTS idx_haccp_actions_user_id ON public.haccp_actions(user_id);
CREATE INDEX IF NOT EXISTS idx_haccp_actions_occurred_at ON public.haccp_actions(occurred_at);
CREATE INDEX IF NOT EXISTS idx_haccp_actions_type ON public.haccp_actions(type);
CREATE INDEX IF NOT EXISTS idx_haccp_actions_user_date ON public.haccp_actions(user_id, occurred_at);

-- ============================================
-- 4. USER_ACCOUNTS (Extended user info with role)
-- ============================================
-- This table extends auth.users with role information
-- Note: We'll use employees table for role, but this can be used for additional user metadata
CREATE TABLE IF NOT EXISTS public.user_accounts (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'employee' CHECK (role IN ('employee', 'manager', 'admin')),
  personnel_id UUID REFERENCES public.personnel(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for user_accounts
CREATE INDEX IF NOT EXISTS idx_user_accounts_role ON public.user_accounts(role);
CREATE INDEX IF NOT EXISTS idx_user_accounts_personnel_id ON public.user_accounts(personnel_id);

-- ============================================
-- TRIGGERS
-- ============================================

-- Update updated_at timestamp for clock_sessions
CREATE OR REPLACE FUNCTION update_clock_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists before creating
DROP TRIGGER IF EXISTS trigger_update_clock_sessions_updated_at ON public.clock_sessions;
CREATE TRIGGER trigger_update_clock_sessions_updated_at
  BEFORE UPDATE ON public.clock_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_clock_sessions_updated_at();

-- Update updated_at timestamp for personnel
CREATE OR REPLACE FUNCTION update_personnel_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists before creating
DROP TRIGGER IF EXISTS trigger_update_personnel_updated_at ON public.personnel;
CREATE TRIGGER trigger_update_personnel_updated_at
  BEFORE UPDATE ON public.personnel
  FOR EACH ROW
  EXECUTE FUNCTION update_personnel_updated_at();

-- Update updated_at timestamp for user_accounts
CREATE OR REPLACE FUNCTION update_user_accounts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists before creating
DROP TRIGGER IF EXISTS trigger_update_user_accounts_updated_at ON public.user_accounts;
CREATE TRIGGER trigger_update_user_accounts_updated_at
  BEFORE UPDATE ON public.user_accounts
  FOR EACH ROW
  EXECUTE FUNCTION update_user_accounts_updated_at();

-- ============================================
-- RLS POLICIES (Row Level Security)
-- ============================================
-- Note: These policies should be added in 02_rls_policies.sql or a separate file
-- For now, we'll enable RLS and add basic policies

-- Enable RLS
ALTER TABLE public.clock_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personnel ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.haccp_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_accounts ENABLE ROW LEVEL SECURITY;

-- Clock sessions: Allow viewing/inserting/updating (app-level validation for employee selection)
-- For shared tablet scenario, RLS is enforced at app level based on employee selection
DROP POLICY IF EXISTS "Users can view clock sessions" ON public.clock_sessions;
CREATE POLICY "Users can view clock sessions"
  ON public.clock_sessions FOR SELECT
  USING (TRUE); -- App will filter by selected employee

DROP POLICY IF EXISTS "Users can insert clock sessions" ON public.clock_sessions;
CREATE POLICY "Users can insert clock sessions"
  ON public.clock_sessions FOR INSERT
  WITH CHECK (TRUE); -- App will validate employee selection

DROP POLICY IF EXISTS "Users can update clock sessions" ON public.clock_sessions;
CREATE POLICY "Users can update clock sessions"
  ON public.clock_sessions FOR UPDATE
  USING (TRUE); -- App will validate employee selection

-- Personnel: Admin only (check via employees.is_admin)
-- Note: This is a simplified policy - in production, you'd check via a function
DROP POLICY IF EXISTS "Admins can view all personnel" ON public.personnel;
CREATE POLICY "Admins can view all personnel"
  ON public.personnel FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.employees
      WHERE employees.created_by = auth.uid()
      AND employees.is_admin = TRUE
    )
  );

DROP POLICY IF EXISTS "Admins can insert personnel" ON public.personnel;
CREATE POLICY "Admins can insert personnel"
  ON public.personnel FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.employees
      WHERE employees.created_by = auth.uid()
      AND employees.is_admin = TRUE
    )
  );

DROP POLICY IF EXISTS "Admins can update personnel" ON public.personnel;
CREATE POLICY "Admins can update personnel"
  ON public.personnel FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.employees
      WHERE employees.created_by = auth.uid()
      AND employees.is_admin = TRUE
    )
  );

DROP POLICY IF EXISTS "Admins can delete personnel" ON public.personnel;
CREATE POLICY "Admins can delete personnel"
  ON public.personnel FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.employees
      WHERE employees.created_by = auth.uid()
      AND employees.is_admin = TRUE
    )
  );

-- HACCP actions: Users can see their own actions, admins can see all
DROP POLICY IF EXISTS "Users can view their own HACCP actions" ON public.haccp_actions;
CREATE POLICY "Users can view their own HACCP actions"
  ON public.haccp_actions FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can view all HACCP actions" ON public.haccp_actions;
CREATE POLICY "Admins can view all HACCP actions"
  ON public.haccp_actions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.employees
      WHERE employees.created_by = auth.uid()
      AND employees.is_admin = TRUE
    )
  );

DROP POLICY IF EXISTS "Users can insert their own HACCP actions" ON public.haccp_actions;
CREATE POLICY "Users can insert their own HACCP actions"
  ON public.haccp_actions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- User accounts: Users can view their own account
DROP POLICY IF EXISTS "Users can view their own account" ON public.user_accounts;
CREATE POLICY "Users can view their own account"
  ON public.user_accounts FOR SELECT
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Admins can view all user accounts" ON public.user_accounts;
CREATE POLICY "Admins can view all user accounts"
  ON public.user_accounts FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.employees
      WHERE employees.created_by = auth.uid()
      AND employees.is_admin = TRUE
    )
  );

DROP POLICY IF EXISTS "Users can update their own account" ON public.user_accounts;
CREATE POLICY "Users can update their own account"
  ON public.user_accounts FOR UPDATE
  USING (auth.uid() = id);

