-- ============================================================
-- TRC RTH — Schema Updates Migration
-- Migration: 20260813_130000_schema_updates.sql
-- ============================================================

-- ── 1. MAINTENANCE RECORDS EXTENSION ────────────────────────
ALTER TABLE public.maintenance_records
  ADD COLUMN IF NOT EXISTS next_maintenance_date DATE,
  ADD COLUMN IF NOT EXISTS maintenance_status TEXT DEFAULT 'Terminé';

-- ── 2. AUDIT ACTION ENUM EXTENSION ───────────────────────────
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'qr_scanned';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'alert_restored';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'login';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'logout';

-- ── 3. UPDATE RLS HELPER FUNCTIONS TO PREFER app_metadata ────
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(
    (SELECT raw_app_meta_data->>'role' FROM auth.users WHERE id = auth.uid()),
    (SELECT raw_user_meta_data->>'role' FROM auth.users WHERE id = auth.uid()),
    'User'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_admin_or_superadmin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND (
      raw_app_meta_data->>'role' IN ('Admin', 'Super Admin')
      OR raw_user_meta_data->>'role' IN ('Admin', 'Super Admin')
    )
  );
$$;

CREATE OR REPLACE FUNCTION public.is_superadmin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND (
      raw_app_meta_data->>'role' = 'Super Admin'
      OR raw_user_meta_data->>'role' = 'Super Admin'
    )
  );
$$;
