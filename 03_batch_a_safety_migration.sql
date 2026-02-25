-- =============================================================================
-- BATCH A — P0 SAFETY MIGRATION
-- "Make the application non-destructive and regulatory-safe"
-- Date: 2026-02-23
-- Author: Senior Engineer / Structural Audit Batch A
-- =============================================================================
-- IMPORTANT: Run this script ONCE on the Supabase SQL editor.
-- All statements are idempotent (IF NOT EXISTS / IF EXISTS guards).
-- The script is split into clearly labelled sections.
-- Rollback instructions are provided at the bottom.
-- =============================================================================

BEGIN;

-- =============================================================================
-- SECTION 1 — REPLACE DESTRUCTIVE CASCADE FKs WITH SET NULL
--
-- Rationale:
--   ON DELETE CASCADE on historical/audit tables means deleting a parent record
--   (e.g. an appareil, a tache, an employee) silently wipes all child records.
--   For a food-safety HACCP application subject to inspections, this is
--   illegal data loss. We replace with SET NULL so the historical row is
--   preserved with a NULL FK, and the legacy text column keeps the name.
-- =============================================================================

-- ── 1.1  temperatures.appareil_id ───────────────────────────────────────────
-- Before: ON DELETE CASCADE  → deleting a device wiped all temperature history
-- After:  ON DELETE SET NULL → temperature row survives with appareil_id = NULL
--         The legacy `appareil` TEXT column already stores the device name, so
--         the reading remains fully readable in the history view.

DO $$
DECLARE v_name text;
BEGIN
  SELECT tc.constraint_name INTO v_name
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
       ON tc.constraint_name = kcu.constraint_name
       AND tc.table_schema   = kcu.table_schema
  WHERE tc.table_schema   = 'public'
    AND tc.table_name     = 'temperatures'
    AND kcu.column_name   = 'appareil_id'
    AND tc.constraint_type = 'FOREIGN KEY'
  LIMIT 1;
  IF v_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.temperatures DROP CONSTRAINT %I', v_name);
    RAISE NOTICE 'Dropped FK %', v_name;
  END IF;
END $$;

ALTER TABLE public.temperatures
  ADD CONSTRAINT temperatures_appareil_id_fkey
  FOREIGN KEY (appareil_id)
  REFERENCES public.appareils(id)
  ON DELETE SET NULL;


-- ── 1.2  nettoyages.tache_id ────────────────────────────────────────────────
-- Before: ON DELETE CASCADE  → deleting a task template wiped all completion records
-- After:  ON DELETE SET NULL → nettoyage row survives with tache_id = NULL
--         The `action` TEXT column on nettoyages stores the task name at record
--         time, so history remains readable.

DO $$
DECLARE v_name text;
BEGIN
  SELECT tc.constraint_name INTO v_name
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
       ON tc.constraint_name = kcu.constraint_name
       AND tc.table_schema   = kcu.table_schema
  WHERE tc.table_schema   = 'public'
    AND tc.table_name     = 'nettoyages'
    AND kcu.column_name   = 'tache_id'
    AND tc.constraint_type = 'FOREIGN KEY'
  LIMIT 1;
  IF v_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.nettoyages DROP CONSTRAINT %I', v_name);
    RAISE NOTICE 'Dropped FK %', v_name;
  END IF;
END $$;

ALTER TABLE public.nettoyages
  ADD CONSTRAINT nettoyages_tache_id_fkey
  FOREIGN KEY (tache_id)
  REFERENCES public.taches_nettoyage(id)
  ON DELETE SET NULL;

-- Also fix the legacy duplicate FK `task_id` if it exists with CASCADE.
-- Wrapped in a full column-existence guard: the column may never have been
-- applied to this Supabase instance (schema drift between 00_schema.sql and
-- the live database). If task_id doesn't exist, skip silently.
DO $$
DECLARE v_name text;
BEGIN
  -- Only proceed if the task_id column actually exists on nettoyages
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'nettoyages'
      AND column_name  = 'task_id'
  ) THEN
    RAISE NOTICE 'Column task_id does not exist on nettoyages — skipping legacy FK patch';
    RETURN;
  END IF;

  -- Drop the existing CASCADE FK if present
  SELECT tc.constraint_name INTO v_name
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
       ON tc.constraint_name = kcu.constraint_name
       AND tc.table_schema   = kcu.table_schema
  WHERE tc.table_schema   = 'public'
    AND tc.table_name     = 'nettoyages'
    AND kcu.column_name   = 'task_id'
    AND tc.constraint_type = 'FOREIGN KEY'
  LIMIT 1;

  IF v_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.nettoyages DROP CONSTRAINT %I', v_name);
    RAISE NOTICE 'Dropped legacy task_id FK %', v_name;
  END IF;

  -- Re-add with SET NULL
  EXECUTE '
    ALTER TABLE public.nettoyages
      ADD CONSTRAINT nettoyages_task_id_fkey
      FOREIGN KEY (task_id)
      REFERENCES public.taches_nettoyage(id)
      ON DELETE SET NULL
  ';
  RAISE NOTICE 'Re-added nettoyages.task_id FK with ON DELETE SET NULL';
END $$;


-- ── 1.3  non_conformities.reception_id ──────────────────────────────────────
-- Before: ON DELETE CASCADE  → deleting a reception destroyed refusal evidence
-- After:  ON DELETE SET NULL → non_conformity row survives as standalone record
--         This is critical: inspectors can request NC records independently of
--         the original reception. Evidence must never be auto-destroyed.

DO $$
DECLARE v_name text;
BEGIN
  SELECT tc.constraint_name INTO v_name
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
       ON tc.constraint_name = kcu.constraint_name
       AND tc.table_schema   = kcu.table_schema
  WHERE tc.table_schema   = 'public'
    AND tc.table_name     = 'non_conformities'
    AND kcu.column_name   = 'reception_id'
    AND tc.constraint_type = 'FOREIGN KEY'
  LIMIT 1;
  IF v_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.non_conformities DROP CONSTRAINT %I', v_name);
    RAISE NOTICE 'Dropped FK %', v_name;
  END IF;
END $$;

ALTER TABLE public.non_conformities
  ADD CONSTRAINT non_conformities_reception_id_fkey
  FOREIGN KEY (reception_id)
  REFERENCES public.receptions(id)
  ON DELETE SET NULL;


-- ── 1.4  clock_sessions.user_id (→ employees.id) ────────────────────────────
-- Before: ON DELETE CASCADE  → deleting an employee wiped all their timesheets
-- After:  ON DELETE SET NULL → timesheet row survives (needed for payroll/legal)
--         Note: this FK references employees.id, NOT auth.users.id.

DO $$
DECLARE v_name text;
BEGIN
  SELECT tc.constraint_name INTO v_name
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
       ON tc.constraint_name = kcu.constraint_name
       AND tc.table_schema   = kcu.table_schema
  WHERE tc.table_schema   = 'public'
    AND tc.table_name     = 'clock_sessions'
    AND kcu.column_name   = 'user_id'
    AND tc.constraint_type = 'FOREIGN KEY'
  LIMIT 1;
  IF v_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.clock_sessions DROP CONSTRAINT %I', v_name);
    RAISE NOTICE 'Dropped FK %', v_name;
  END IF;
END $$;

-- Note: user_id is NOT NULL. After SET NULL the column must be nullable.
-- We make it nullable first, then re-add the FK.
ALTER TABLE public.clock_sessions
  ALTER COLUMN user_id DROP NOT NULL;

ALTER TABLE public.clock_sessions
  ADD CONSTRAINT clock_sessions_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES public.employees(id)
  ON DELETE SET NULL;


-- ── 1.5  oil_changes.friteuse_id ────────────────────────────────────────────
-- Before: ON DELETE CASCADE  → deleting a fryer wiped all oil change history
-- After:  ON DELETE SET NULL → oil_change row survives with friteuse_id = NULL
--         The `type_huile` and `changed_at` columns make the record still
--         useful for HACCP compliance without the parent fryer reference.
--
-- ⚠ SCHEMA DRIFT GUARD: In production, oil_changes.friteuse_id may be TEXT
--   while friteuses.id is UUID — a type mismatch that prevents FK enforcement.
--   We detect the column type at runtime and branch accordingly:
--     • If TEXT  → skip FK; emit a NOTICE with the manual resolution command
--     • If UUID  → drop existing CASCADE FK (if any) and re-add with SET NULL
--
-- To manually resolve the type mismatch (run SEPARATELY after validating that
-- all existing friteuse_id values are valid UUID strings):
--
--   ALTER TABLE public.oil_changes
--     ALTER COLUMN friteuse_id TYPE UUID USING friteuse_id::UUID;
--
-- After that, re-run this section (or the full migration) to add the FK.

DO $$
DECLARE
  v_name     text;
  v_col_type text;
BEGIN
  -- 1. Check that the column exists and read its type
  SELECT data_type INTO v_col_type
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name   = 'oil_changes'
    AND column_name  = 'friteuse_id'
  LIMIT 1;

  IF v_col_type IS NULL THEN
    RAISE NOTICE '⚠ Column oil_changes.friteuse_id not found — skipping FK patch (§1.5)';
    RETURN;
  END IF;

  -- 2. If the column is TEXT, FK cannot be enforced against a UUID primary key
  IF v_col_type <> 'uuid' THEN
    RAISE NOTICE '⚠ §1.5 SKIPPED: oil_changes.friteuse_id is type "%" (expected uuid). '
                 'Run the type-cast command documented in §1.5 of this file, then '
                 're-run the migration to add the FK with ON DELETE SET NULL.',
                 v_col_type;
    RETURN;
  END IF;

  -- 3. Column is UUID — safe to proceed.
  --    Drop the existing CASCADE FK if one is present.
  SELECT tc.constraint_name INTO v_name
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
       ON tc.constraint_name = kcu.constraint_name
       AND tc.table_schema   = kcu.table_schema
  WHERE tc.table_schema    = 'public'
    AND tc.table_name      = 'oil_changes'
    AND kcu.column_name    = 'friteuse_id'
    AND tc.constraint_type = 'FOREIGN KEY'
  LIMIT 1;

  IF v_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.oil_changes DROP CONSTRAINT %I', v_name);
    RAISE NOTICE 'Dropped FK %', v_name;
  END IF;

  -- 4. Re-add with SET NULL
  EXECUTE '
    ALTER TABLE public.oil_changes
      ADD CONSTRAINT oil_changes_friteuse_id_fkey
      FOREIGN KEY (friteuse_id)
      REFERENCES public.friteuses(id)
      ON DELETE SET NULL
  ';
  RAISE NOTICE '✅ Re-added oil_changes.friteuse_id FK with ON DELETE SET NULL';
END $$;


-- =============================================================================
-- SECTION 2 — SOFT-DELETE COLUMNS
--
-- Rationale:
--   Instead of physically removing rows from master tables, we mark them as
--   deleted. This preserves referential integrity for all child tables and
--   provides a full audit trail. Hard delete is DISABLED at the app layer.
--
--   Two columns per table:
--     • is_deleted BOOLEAN DEFAULT FALSE  — fast filter column, indexed
--     • deleted_at TIMESTAMPTZ            — when it was soft-deleted (audit)
--
--   NOT adding NOT NULL to deleted_at: NULL means "not deleted", consistent
--   with how `end_date = NULL` means "still active" in the personnel table.
-- =============================================================================

-- ── 2.1  appareils ──────────────────────────────────────────────────────────
ALTER TABLE public.appareils
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_appareils_is_deleted
  ON public.appareils(is_deleted)
  WHERE is_deleted = FALSE;

-- ── 2.2  taches_nettoyage ────────────────────────────────────────────────────
ALTER TABLE public.taches_nettoyage
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_taches_nettoyage_is_deleted
  ON public.taches_nettoyage(is_deleted)
  WHERE is_deleted = FALSE;

-- ── 2.3  produits ────────────────────────────────────────────────────────────
-- NOTE: produits already has `actif BOOLEAN`. We add is_deleted separately
-- because `actif` means "active in catalogue" (business logic), while
-- `is_deleted` means "physically removed from UI" (data governance).
-- The two are orthogonal: a product can be inactive (retired) but not deleted.
ALTER TABLE public.produits
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_produits_is_deleted
  ON public.produits(is_deleted)
  WHERE is_deleted = FALSE;

-- ── 2.4  friteuses ───────────────────────────────────────────────────────────
ALTER TABLE public.friteuses
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_friteuses_is_deleted
  ON public.friteuses(is_deleted)
  WHERE is_deleted = FALSE;

-- ── 2.5  employees ───────────────────────────────────────────────────────────
-- NOTE: employees already has `is_active BOOLEAN`. Same reasoning as produits:
-- `is_active` = business status, `is_deleted` = governance / soft-delete.
ALTER TABLE public.employees
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_employees_is_deleted
  ON public.employees(is_deleted)
  WHERE is_deleted = FALSE;


-- =============================================================================
-- SECTION 3 — SNAPSHOT COLUMNS (Denormalisation for historical readability)
--
-- Rationale:
--   After SET NULL, child records lose their FK reference. We add snapshot
--   columns that capture the parent name AT WRITE TIME. This lets history
--   views show "Frigo 1 (supprimé)" rather than a blank.
-- =============================================================================

-- ── 3.1  temperatures: snapshot of device name ──────────────────────────────
-- The `appareil` TEXT column already exists for this purpose (legacy column).
-- We document its intended use here. No schema change needed.
-- CONVENTION: when creating a temperature record, always write `appareil` = device name.
-- This is enforced in the Flutter repo layer (see TemperatureRepository).

-- ── 3.2  nettoyages: snapshot of task name ──────────────────────────────────
-- The `action` TEXT column exists but may not be consistently populated.
-- Add a dedicated snapshot column.
ALTER TABLE public.nettoyages
  ADD COLUMN IF NOT EXISTS tache_nom_snapshot TEXT;

COMMENT ON COLUMN public.nettoyages.tache_nom_snapshot IS
  'Snapshot of taches_nettoyage.nom at record creation time. '
  'Preserved when the parent task is soft-deleted.';

-- ── 3.3  oil_changes: snapshot of fryer name ────────────────────────────────
ALTER TABLE public.oil_changes
  ADD COLUMN IF NOT EXISTS friteuse_nom_snapshot TEXT;

COMMENT ON COLUMN public.oil_changes.friteuse_nom_snapshot IS
  'Snapshot of friteuses.nom at record creation time. '
  'Preserved when the parent fryer is soft-deleted.';

-- ── 3.4  clock_sessions: snapshot of employee name ──────────────────────────
ALTER TABLE public.clock_sessions
  ADD COLUMN IF NOT EXISTS employee_name_snapshot TEXT;

COMMENT ON COLUMN public.clock_sessions.employee_name_snapshot IS
  'Snapshot of employees full name at session creation time. '
  'Preserved when the employee is soft-deleted.';


-- =============================================================================
-- SECTION 4 — AUDIT_LOG INTEGRITY
--
-- Rationale:
--   audit_log.operation_id is a UUID with no FK constraint. After a record is
--   deleted (physically), audit_log entries become orphaned and misleading.
--
--   Strategy: Add a trigger that fires AFTER a soft-delete UPDATE (is_deleted=TRUE)
--   and writes a metadata entry to the audit_log marking the deletion.
--   We do NOT delete audit_log rows: they are append-only evidence.
--   Instead, the trigger adds a 'soft_delete' action entry so the log is
--   self-consistent.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_audit_soft_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only act when is_deleted transitions FALSE → TRUE
  IF OLD.is_deleted = FALSE AND NEW.is_deleted = TRUE THEN
    INSERT INTO public.audit_log (
      organization_id,
      operation_type,
      operation_id,
      action,
      actor_user_id,
      description,
      metadata,
      created_at
    )
    SELECT
      -- organization_id: use owner_id as proxy if org column doesn't exist on this table
      COALESCE(
        (NEW::jsonb)->>'organization_id',
        (NEW::jsonb)->>'owner_id'
      )::UUID,
      TG_TABLE_NAME,   -- 'appareils', 'taches_nettoyage', etc.
      NEW.id::UUID,
      'soft_delete',
      auth.uid(),
      format('Record soft-deleted from table %s (id=%s)', TG_TABLE_NAME, NEW.id),
      jsonb_build_object(
        'table',      TG_TABLE_NAME,
        'id',         NEW.id,
        'deleted_at', NEW.deleted_at,
        'is_deleted', NEW.is_deleted
      ),
      NOW()
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

-- Attach trigger to each soft-delete table
DROP TRIGGER IF EXISTS trg_audit_soft_delete_appareils        ON public.appareils;
DROP TRIGGER IF EXISTS trg_audit_soft_delete_taches_nettoyage ON public.taches_nettoyage;
DROP TRIGGER IF EXISTS trg_audit_soft_delete_produits         ON public.produits;
DROP TRIGGER IF EXISTS trg_audit_soft_delete_friteuses        ON public.friteuses;
DROP TRIGGER IF EXISTS trg_audit_soft_delete_employees        ON public.employees;

CREATE TRIGGER trg_audit_soft_delete_appareils
  AFTER UPDATE OF is_deleted ON public.appareils
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_soft_delete();

CREATE TRIGGER trg_audit_soft_delete_taches_nettoyage
  AFTER UPDATE OF is_deleted ON public.taches_nettoyage
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_soft_delete();

CREATE TRIGGER trg_audit_soft_delete_produits
  AFTER UPDATE OF is_deleted ON public.produits
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_soft_delete();

CREATE TRIGGER trg_audit_soft_delete_friteuses
  AFTER UPDATE OF is_deleted ON public.friteuses
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_soft_delete();

CREATE TRIGGER trg_audit_soft_delete_employees
  AFTER UPDATE OF is_deleted ON public.employees
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_soft_delete();


-- =============================================================================
-- SECTION 5 — RLS POLICY UPDATES
--
-- Existing RLS policies filter by owner_id = auth.uid().
-- After soft-delete, SELECT policies must also exclude is_deleted = TRUE.
-- Since we cannot see the existing policy names here, this section provides
-- the pattern. Apply in Supabase Dashboard → Table Editor → RLS Policies,
-- or add these after confirming existing policy names.
--
-- Example for appareils (repeat for each table):
--   DROP POLICY IF EXISTS "Users see own appareils" ON public.appareils;
--   CREATE POLICY "Users see own active appareils"
--     ON public.appareils FOR SELECT
--     USING (owner_id = auth.uid() AND is_deleted = FALSE);
-- =============================================================================

-- Placeholder — uncomment and customise after auditing existing policy names:
-- ALTER POLICY "your_existing_policy_name" ON public.appareils
--   USING (owner_id = auth.uid() AND is_deleted = FALSE);


-- =============================================================================
-- SECTION 6 — VERIFICATION QUERIES
-- Run these after applying the migration to confirm all changes took effect.
-- =============================================================================

-- 6.1 Check FK ON DELETE behaviour
-- Expected: all 5 rows show 'a' (SET NULL), not 'c' (CASCADE)
/*
SELECT
  tc.table_name,
  kcu.column_name,
  rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
     ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
JOIN information_schema.referential_constraints rc
     ON tc.constraint_name = rc.constraint_name
WHERE tc.table_schema = 'public'
  AND tc.table_name IN ('temperatures','nettoyages','non_conformities','clock_sessions','oil_changes')
  AND kcu.column_name IN ('appareil_id','tache_id','reception_id','user_id','friteuse_id')
ORDER BY tc.table_name;
*/

-- 6.2 Check soft-delete columns exist
/*
SELECT table_name, column_name, data_type, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND column_name IN ('is_deleted','deleted_at')
ORDER BY table_name, column_name;
*/

-- 6.3 Check triggers exist
/*
SELECT trigger_name, event_object_table, action_timing, event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name LIKE 'trg_audit_soft_delete_%'
ORDER BY event_object_table;
*/


COMMIT;


-- =============================================================================
-- ROLLBACK SCRIPT (save separately — DO NOT run unless reverting)
-- =============================================================================
/*
BEGIN;

-- Revert FK constraints back to CASCADE
ALTER TABLE public.temperatures    DROP CONSTRAINT IF EXISTS temperatures_appareil_id_fkey;
ALTER TABLE public.temperatures    ADD CONSTRAINT temperatures_appareil_id_fkey    FOREIGN KEY (appareil_id)   REFERENCES public.appareils(id)         ON DELETE CASCADE;

ALTER TABLE public.nettoyages      DROP CONSTRAINT IF EXISTS nettoyages_tache_id_fkey;
ALTER TABLE public.nettoyages      ADD CONSTRAINT nettoyages_tache_id_fkey         FOREIGN KEY (tache_id)      REFERENCES public.taches_nettoyage(id)  ON DELETE CASCADE;
-- task_id rollback: only if column exists (may not be present on all instances)
-- ALTER TABLE public.nettoyages DROP CONSTRAINT IF EXISTS nettoyages_task_id_fkey;
-- ALTER TABLE public.nettoyages ADD CONSTRAINT nettoyages_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.taches_nettoyage(id) ON DELETE CASCADE;

ALTER TABLE public.non_conformities DROP CONSTRAINT IF EXISTS non_conformities_reception_id_fkey;
ALTER TABLE public.non_conformities ADD CONSTRAINT non_conformities_reception_id_fkey FOREIGN KEY (reception_id) REFERENCES public.receptions(id)       ON DELETE CASCADE;

ALTER TABLE public.clock_sessions  DROP CONSTRAINT IF EXISTS clock_sessions_user_id_fkey;
ALTER TABLE public.clock_sessions  ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE public.clock_sessions  ADD CONSTRAINT clock_sessions_user_id_fkey      FOREIGN KEY (user_id)       REFERENCES public.employees(id)         ON DELETE CASCADE;

ALTER TABLE public.oil_changes     DROP CONSTRAINT IF EXISTS oil_changes_friteuse_id_fkey;
-- NOTE: Only re-add the CASCADE FK if friteuse_id is UUID type.
-- If it was TEXT in production the FK was never in place; omit to avoid repeat type error.
-- ALTER TABLE public.oil_changes  ADD CONSTRAINT oil_changes_friteuse_id_fkey FOREIGN KEY (friteuse_id) REFERENCES public.friteuses(id) ON DELETE CASCADE;

-- Remove soft-delete columns
ALTER TABLE public.appareils        DROP COLUMN IF EXISTS is_deleted, DROP COLUMN IF EXISTS deleted_at;
ALTER TABLE public.taches_nettoyage DROP COLUMN IF EXISTS is_deleted, DROP COLUMN IF EXISTS deleted_at;
ALTER TABLE public.produits         DROP COLUMN IF EXISTS is_deleted, DROP COLUMN IF EXISTS deleted_at;
ALTER TABLE public.friteuses        DROP COLUMN IF EXISTS is_deleted, DROP COLUMN IF EXISTS deleted_at;
ALTER TABLE public.employees        DROP COLUMN IF EXISTS is_deleted, DROP COLUMN IF EXISTS deleted_at;

-- Remove snapshot columns
ALTER TABLE public.nettoyages    DROP COLUMN IF EXISTS tache_nom_snapshot;
ALTER TABLE public.oil_changes   DROP COLUMN IF EXISTS friteuse_nom_snapshot;
ALTER TABLE public.clock_sessions DROP COLUMN IF EXISTS employee_name_snapshot;

-- Remove triggers and function
DROP TRIGGER IF EXISTS trg_audit_soft_delete_appareils        ON public.appareils;
DROP TRIGGER IF EXISTS trg_audit_soft_delete_taches_nettoyage ON public.taches_nettoyage;
DROP TRIGGER IF EXISTS trg_audit_soft_delete_produits         ON public.produits;
DROP TRIGGER IF EXISTS trg_audit_soft_delete_friteuses        ON public.friteuses;
DROP TRIGGER IF EXISTS trg_audit_soft_delete_employees        ON public.employees;
DROP FUNCTION IF EXISTS public.fn_audit_soft_delete();

COMMIT;
*/
