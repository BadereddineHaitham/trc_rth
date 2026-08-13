-- ============================================================
-- RTH Fleet Management — Full Database Schema
-- Migration: 20260813090000_rth_fleet_management.sql
-- ============================================================

-- ── 1. ENUMS ────────────────────────────────────────────────
DROP TYPE IF EXISTS public.vehicle_status CASCADE;
CREATE TYPE public.vehicle_status AS ENUM ('operational', 'maintenance', 'out_of_service');

DROP TYPE IF EXISTS public.alert_severity CASCADE;
CREATE TYPE public.alert_severity AS ENUM ('ok', 'warning', 'critical');

DROP TYPE IF EXISTS public.alert_category CASCADE;
CREATE TYPE public.alert_category AS ENUM ('insurance', 'inspection', 'maintenance', 'equipment');

DROP TYPE IF EXISTS public.maintenance_type CASCADE;
CREATE TYPE public.maintenance_type AS ENUM ('Préventive', 'Corrective', 'Vidange', 'Réparation', 'Inspection');

DROP TYPE IF EXISTS public.audit_action CASCADE;
CREATE TYPE public.audit_action AS ENUM (
  'vehicle_created', 'vehicle_updated', 'vehicle_deleted',
  'maintenance_added', 'maintenance_updated',
  'equipment_updated', 'alert_dismissed',
  'user_created', 'user_updated', 'user_disabled', 'user_enabled',
  'park_created', 'park_updated'
);

-- ── 2. CORE TABLES ──────────────────────────────────────────

-- Parks (fire stations / sites)
CREATE TABLE IF NOT EXISTS public.parks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  location TEXT NOT NULL DEFAULT '',
  description TEXT DEFAULT '',
  qr_code TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Vehicles
CREATE TABLE IF NOT EXISTS public.vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  park_id UUID REFERENCES public.parks(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  vehicle_type TEXT NOT NULL DEFAULT '',
  matricule TEXT NOT NULL DEFAULT '',
  status public.vehicle_status NOT NULL DEFAULT 'operational',
  insurance_start DATE,
  insurance_expiry DATE,
  inspection_expiry DATE,
  oil_change_date DATE,
  general_remark TEXT DEFAULT '',
  water_capacity TEXT DEFAULT '',
  emulsifier_capacity TEXT DEFAULT '',
  powder_capacity TEXT DEFAULT '',
  cannon_range TEXT DEFAULT '',
  missing_equipment_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Equipment definitions (catalog)
CREATE TABLE IF NOT EXISTS public.equipment_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  unit TEXT NOT NULL DEFAULT 'unité',
  default_standard INTEGER NOT NULL DEFAULT 1,
  active BOOLEAN NOT NULL DEFAULT true,
  description TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Vehicle equipment inventory (per vehicle)
CREATE TABLE IF NOT EXISTS public.vehicle_equipment (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
  equipment_definition_id UUID NOT NULL REFERENCES public.equipment_definitions(id) ON DELETE CASCADE,
  standard_quantity INTEGER NOT NULL DEFAULT 0,
  existing_quantity INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(vehicle_id, equipment_definition_id)
);

-- Fixed equipment (fire posts, extinguishers, etc.)
CREATE TABLE IF NOT EXISTS public.fixed_equipment (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  park_id UUID REFERENCES public.parks(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT '',
  location TEXT NOT NULL DEFAULT '',
  status public.vehicle_status NOT NULL DEFAULT 'operational',
  last_inspection DATE,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Maintenance records
CREATE TABLE IF NOT EXISTS public.maintenance_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
  maintenance_date DATE NOT NULL,
  maintenance_type public.maintenance_type NOT NULL DEFAULT 'Préventive',
  description TEXT NOT NULL DEFAULT '',
  provider TEXT DEFAULT '',
  responsible TEXT DEFAULT '',
  observation TEXT DEFAULT '',
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Alerts
CREATE TABLE IF NOT EXISTS public.alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE CASCADE,
  category public.alert_category NOT NULL,
  severity public.alert_severity NOT NULL DEFAULT 'warning',
  title TEXT NOT NULL,
  subtitle TEXT NOT NULL DEFAULT '',
  vehicle_name TEXT NOT NULL DEFAULT '',
  detail TEXT DEFAULT '',
  dismissed BOOLEAN NOT NULL DEFAULT false,
  dismissed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  dismissed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Audit log
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  username TEXT NOT NULL DEFAULT '',
  action public.audit_action NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  entity_type TEXT DEFAULT '',
  entity_id UUID,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ── 3. INDEXES ──────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_vehicles_park_id ON public.vehicles(park_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_status ON public.vehicles(status);
CREATE INDEX IF NOT EXISTS idx_vehicle_equipment_vehicle_id ON public.vehicle_equipment(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_vehicle_id ON public.maintenance_records(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_date ON public.maintenance_records(maintenance_date DESC);
CREATE INDEX IF NOT EXISTS idx_alerts_vehicle_id ON public.alerts(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_alerts_severity ON public.alerts(severity);
CREATE INDEX IF NOT EXISTS idx_alerts_dismissed ON public.alerts(dismissed);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fixed_equipment_park_id ON public.fixed_equipment(park_id);

-- ── 4. FUNCTIONS ────────────────────────────────────────────

-- Role check from auth metadata (safe, no recursion)
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(
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
      raw_user_meta_data->>'role' IN ('Admin', 'Super Admin')
      OR raw_app_meta_data->>'role' IN ('Admin', 'Super Admin')
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
      raw_user_meta_data->>'role' = 'Super Admin'
      OR raw_app_meta_data->>'role' = 'Super Admin'
    )
  );
$$;

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;

-- Recalculate missing equipment count on vehicle
CREATE OR REPLACE FUNCTION public.recalculate_missing_equipment(p_vehicle_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  missing_count INTEGER;
BEGIN
  SELECT COALESCE(SUM(GREATEST(standard_quantity - existing_quantity, 0)), 0)
  INTO missing_count
  FROM public.vehicle_equipment
  WHERE vehicle_id = p_vehicle_id;

  UPDATE public.vehicles
  SET missing_equipment_count = missing_count, updated_at = CURRENT_TIMESTAMP
  WHERE id = p_vehicle_id;
END;
$$;

-- Trigger function to recalculate missing equipment
CREATE OR REPLACE FUNCTION public.trigger_recalculate_missing()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.recalculate_missing_equipment(OLD.vehicle_id);
  ELSE
    PERFORM public.recalculate_missing_equipment(NEW.vehicle_id);
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- ── 5. ENABLE RLS ───────────────────────────────────────────
ALTER TABLE public.parks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equipment_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fixed_equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- ── 6. RLS POLICIES ─────────────────────────────────────────

-- Parks: public read, admin write
DROP POLICY IF EXISTS "parks_public_read" ON public.parks;
CREATE POLICY "parks_public_read" ON public.parks FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "parks_admin_write" ON public.parks;
CREATE POLICY "parks_admin_write" ON public.parks FOR ALL TO authenticated
  USING (public.is_admin_or_superadmin())
  WITH CHECK (public.is_admin_or_superadmin());

-- Vehicles: public read, admin write
DROP POLICY IF EXISTS "vehicles_public_read" ON public.vehicles;
CREATE POLICY "vehicles_public_read" ON public.vehicles FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "vehicles_admin_write" ON public.vehicles;
CREATE POLICY "vehicles_admin_write" ON public.vehicles FOR ALL TO authenticated
  USING (public.is_admin_or_superadmin())
  WITH CHECK (public.is_admin_or_superadmin());

-- Equipment definitions: public read, admin write
DROP POLICY IF EXISTS "equip_def_public_read" ON public.equipment_definitions;
CREATE POLICY "equip_def_public_read" ON public.equipment_definitions FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "equip_def_admin_write" ON public.equipment_definitions;
CREATE POLICY "equip_def_admin_write" ON public.equipment_definitions FOR ALL TO authenticated
  USING (public.is_admin_or_superadmin())
  WITH CHECK (public.is_admin_or_superadmin());

-- Vehicle equipment: public read, admin write
DROP POLICY IF EXISTS "vehicle_equip_public_read" ON public.vehicle_equipment;
CREATE POLICY "vehicle_equip_public_read" ON public.vehicle_equipment FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "vehicle_equip_admin_write" ON public.vehicle_equipment;
CREATE POLICY "vehicle_equip_admin_write" ON public.vehicle_equipment FOR ALL TO authenticated
  USING (public.is_admin_or_superadmin())
  WITH CHECK (public.is_admin_or_superadmin());

-- Fixed equipment: public read, admin write
DROP POLICY IF EXISTS "fixed_equip_public_read" ON public.fixed_equipment;
CREATE POLICY "fixed_equip_public_read" ON public.fixed_equipment FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "fixed_equip_admin_write" ON public.fixed_equipment;
CREATE POLICY "fixed_equip_admin_write" ON public.fixed_equipment FOR ALL TO authenticated
  USING (public.is_admin_or_superadmin())
  WITH CHECK (public.is_admin_or_superadmin());

-- Maintenance records: public read, admin write
DROP POLICY IF EXISTS "maintenance_public_read" ON public.maintenance_records;
CREATE POLICY "maintenance_public_read" ON public.maintenance_records FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "maintenance_admin_write" ON public.maintenance_records;
CREATE POLICY "maintenance_admin_write" ON public.maintenance_records FOR ALL TO authenticated
  USING (public.is_admin_or_superadmin())
  WITH CHECK (public.is_admin_or_superadmin());

-- Alerts: public read, admin write
DROP POLICY IF EXISTS "alerts_public_read" ON public.alerts;
CREATE POLICY "alerts_public_read" ON public.alerts FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "alerts_admin_write" ON public.alerts;
CREATE POLICY "alerts_admin_write" ON public.alerts FOR ALL TO authenticated
  USING (public.is_admin_or_superadmin())
  WITH CHECK (public.is_admin_or_superadmin());

-- Audit logs: admin read, admin write
DROP POLICY IF EXISTS "audit_admin_read" ON public.audit_logs;
CREATE POLICY "audit_admin_read" ON public.audit_logs FOR SELECT TO authenticated
  USING (public.is_admin_or_superadmin());

DROP POLICY IF EXISTS "audit_admin_write" ON public.audit_logs;
CREATE POLICY "audit_admin_write" ON public.audit_logs FOR INSERT TO authenticated
  WITH CHECK (public.is_admin_or_superadmin());

-- ── 7. TRIGGERS ─────────────────────────────────────────────
DROP TRIGGER IF EXISTS set_updated_at_parks ON public.parks;
CREATE TRIGGER set_updated_at_parks BEFORE UPDATE ON public.parks
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at_vehicles ON public.vehicles;
CREATE TRIGGER set_updated_at_vehicles BEFORE UPDATE ON public.vehicles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at_equipment_definitions ON public.equipment_definitions;
CREATE TRIGGER set_updated_at_equipment_definitions BEFORE UPDATE ON public.equipment_definitions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at_vehicle_equipment ON public.vehicle_equipment;
CREATE TRIGGER set_updated_at_vehicle_equipment BEFORE UPDATE ON public.vehicle_equipment
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at_fixed_equipment ON public.fixed_equipment;
CREATE TRIGGER set_updated_at_fixed_equipment BEFORE UPDATE ON public.fixed_equipment
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at_maintenance ON public.maintenance_records;
CREATE TRIGGER set_updated_at_maintenance BEFORE UPDATE ON public.maintenance_records
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at_alerts ON public.alerts;
CREATE TRIGGER set_updated_at_alerts BEFORE UPDATE ON public.alerts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS recalculate_missing_on_equip_change ON public.vehicle_equipment;
CREATE TRIGGER recalculate_missing_on_equip_change
  AFTER INSERT OR UPDATE OR DELETE ON public.vehicle_equipment
  FOR EACH ROW EXECUTE FUNCTION public.trigger_recalculate_missing();

-- ── 8. SEED DATA ────────────────────────────────────────────
DO $$
DECLARE
  park_uuid UUID := gen_random_uuid();
  v_vmr80_1 UUID := gen_random_uuid();
  v_vmr80_2 UUID := gen_random_uuid();
  v_vmr115_1 UUID := gen_random_uuid();
  v_vmr115_2 UUID := gen_random_uuid();
  v_isuzu UUID := gen_random_uuid();
  v_astra UUID := gen_random_uuid();

  eq_tuyau100 UUID := gen_random_uuid();
  eq_tuyau70 UUID := gen_random_uuid();
  eq_tuyau45 UUID := gen_random_uuid();
  eq_lance45 UUID := gen_random_uuid();
  eq_lance70 UUID := gen_random_uuid();
  eq_lance_mousse70 UUID := gen_random_uuid();
  eq_lance_mousse45 UUID := gen_random_uuid();
  eq_red100_70 UUID := gen_random_uuid();
  eq_red150_100 UUID := gen_random_uuid();
  eq_red70_45 UUID := gen_random_uuid();
  eq_div100_70 UUID := gen_random_uuid();
  eq_div70_45 UUID := gen_random_uuid();
  eq_ari UUID := gen_random_uuid();
  eq_tenue_pen UUID := gen_random_uuid();
  eq_tenue_app UUID := gen_random_uuid();
  eq_masque UUID := gen_random_uuid();
  eq_gants UUID := gen_random_uuid();
  eq_lunette UUID := gen_random_uuid();
  eq_extincteur UUID := gen_random_uuid();
  eq_extincteur_co2 UUID := gen_random_uuid();
  eq_hache UUID := gen_random_uuid();
  eq_cisailles UUID := gen_random_uuid();
  eq_pelle UUID := gen_random_uuid();
  eq_pioche UUID := gen_random_uuid();
  eq_marteau UUID := gen_random_uuid();
  eq_arrache UUID := gen_random_uuid();
  eq_cle_f UUID := gen_random_uuid();
  eq_cle_carree UUID := gen_random_uuid();
  eq_perche UUID := gen_random_uuid();
  eq_tricoises UUID := gen_random_uuid();
  eq_crepine UUID := gen_random_uuid();
  eq_flotteur UUID := gen_random_uuid();

BEGIN
  -- Park
  INSERT INTO public.parks (id, name, location, description, qr_code)
  VALUES (park_uuid, 'Parc RTH Hassi Messaoud', 'Hassi Messaoud, Ouargla', 'Parc de lutte contre incendie RTH', 'RTH-PARK-001')
  ON CONFLICT (id) DO NOTHING;

  -- Vehicles
  INSERT INTO public.vehicles (id, park_id, name, vehicle_type, matricule, status, insurance_start, insurance_expiry, inspection_expiry, oil_change_date, general_remark, water_capacity, emulsifier_capacity, powder_capacity, cannon_range, missing_equipment_count)
  VALUES
    (v_vmr80_1, park_uuid, 'VMR 80 N°1', 'VMR 80', '00664-209-29', 'operational', '2026-07-17', '2026-12-31', '2026-09-23', '2026-06-10', '', '3.5 m³', '8 m³', '1 T', '40 m', 0),
    (v_vmr80_2, park_uuid, 'VMR 80 N°2', 'VMR 80', '00664-209-30', 'operational', '2026-07-17', '2026-12-31', '2026-09-23', '2026-06-10', 'Camion indisponible (pompe émulseur en cours de réparation)', '3.5 m³', '8 m³', '1 T', '45 m', 2),
    (v_vmr115_1, park_uuid, 'VMR 115 N°1', 'VMR 115', '00664-215-01', 'operational', '2026-06-01', '2026-11-30', '2026-10-15', '2026-07-20', '', '5.0 m³', '10 m³', '2 T', '55 m', 1),
    (v_vmr115_2, park_uuid, 'VMR 115 N°2', 'VMR 115', '00664-215-02', 'maintenance', '2026-06-01', '2026-11-30', '2026-08-05', '2026-05-15', 'Véhicule en maintenance préventive — révision complète de la pompe', '5.0 m³', '10 m³', '2 T', '55 m', 0),
    (v_isuzu, park_uuid, 'ISUZU', 'Véhicule léger', '00664-190-12', 'operational', '2026-05-01', '2026-10-31', '2026-09-01', '2026-06-25', '', '1.0 m³', '2 m³', '0.5 T', '20 m', 0),
    (v_astra, park_uuid, 'ASTRA', 'Camion citerne', '00664-180-08', 'out_of_service', '2026-02-01', '2026-07-31', '2026-06-15', '2026-04-10', 'Hors service — révision moteur complète en cours. Retour prévu fin septembre 2026.', '8.0 m³', '15 m³', '3 T', '65 m', 5)
  ON CONFLICT (id) DO NOTHING;

  -- Fixed equipment
  INSERT INTO public.fixed_equipment (park_id, name, category, location, status, last_inspection)
  VALUES
    (park_uuid, 'Poste incendie fixe N°1', 'Réseau incendie', 'Zone A - Entrée principale', 'operational', '2026-07-15'),
    (park_uuid, 'Poste incendie fixe N°2', 'Réseau incendie', 'Zone B - Unité de traitement', 'operational', '2026-07-15'),
    (park_uuid, 'Extincteurs fixes Zone C', 'Extinction fixe', 'Zone C - Stockage', 'maintenance', '2026-05-20')
  ON CONFLICT (id) DO NOTHING;

  -- Equipment definitions
  INSERT INTO public.equipment_definitions (id, name, category, unit, default_standard)
  VALUES
    (eq_tuyau100, 'Tuyau Ø100', 'Tuyaux', 'unité', 10),
    (eq_tuyau70, 'Tuyau Ø70', 'Tuyaux', 'unité', 8),
    (eq_tuyau45, 'Tuyau Ø45', 'Tuyaux', 'unité', 6),
    (eq_lance45, 'Lance à eau Ø45 LDV', 'Lances', 'unité', 2),
    (eq_lance70, 'Lance à eau Ø70', 'Lances', 'unité', 2),
    (eq_lance_mousse70, 'Lance à mousse Ø70', 'Lances', 'unité', 1),
    (eq_lance_mousse45, 'Lance à mousse Ø45', 'Lances', 'unité', 1),
    (eq_red100_70, 'Réduction Ø100-70', 'Raccords', 'unité', 4),
    (eq_red150_100, 'Réduction Ø150-100', 'Raccords', 'unité', 2),
    (eq_red70_45, 'Réduction Ø70-45', 'Raccords', 'unité', 4),
    (eq_div100_70, 'Division Ø100-70', 'Raccords', 'unité', 2),
    (eq_div70_45, 'Division Ø70-45', 'Raccords', 'unité', 2),
    (eq_ari, 'ARI', 'Protection', 'unité', 2),
    (eq_tenue_pen, 'Tenue de pénétration', 'Protection', 'unité', 2),
    (eq_tenue_app, 'Tenue d''approche', 'Protection', 'unité', 2),
    (eq_masque, 'Masque', 'Protection', 'unité', 2),
    (eq_gants, 'Gants', 'Protection', 'paire', 4),
    (eq_lunette, 'Lunette', 'Protection', 'unité', 2),
    (eq_extincteur, 'Extincteur', 'Extinction', 'unité', 2),
    (eq_extincteur_co2, 'Extincteur CO2', 'Extinction', 'unité', 1),
    (eq_hache, 'Hache', 'Outils', 'unité', 2),
    (eq_cisailles, 'Cisailles', 'Outils', 'unité', 1),
    (eq_pelle, 'Pelle', 'Outils', 'unité', 2),
    (eq_pioche, 'Pioche', 'Outils', 'unité', 1),
    (eq_marteau, 'Marteau', 'Outils', 'unité', 1),
    (eq_arrache, 'Arrache-clou', 'Outils', 'unité', 1),
    (eq_cle_f, 'Clé F', 'Outils', 'unité', 2),
    (eq_cle_carree, 'Clé carrée', 'Outils', 'unité', 2),
    (eq_perche, 'Perche', 'Outils', 'unité', 1),
    (eq_tricoises, 'Tricoises', 'Outils', 'unité', 1),
    (eq_crepine, 'Crépine', 'Aspiration', 'unité', 2),
    (eq_flotteur, 'Flotteur', 'Aspiration', 'unité', 1)
  ON CONFLICT (id) DO NOTHING;

  -- Vehicle equipment for VMR 80 N°1 (all complete)
  INSERT INTO public.vehicle_equipment (vehicle_id, equipment_definition_id, standard_quantity, existing_quantity)
  VALUES
    (v_vmr80_1, eq_tuyau100, 10, 10), (v_vmr80_1, eq_tuyau70, 8, 8), (v_vmr80_1, eq_tuyau45, 6, 6),
    (v_vmr80_1, eq_lance45, 2, 2), (v_vmr80_1, eq_lance70, 2, 2), (v_vmr80_1, eq_lance_mousse70, 1, 1),
    (v_vmr80_1, eq_lance_mousse45, 1, 1), (v_vmr80_1, eq_red100_70, 4, 4), (v_vmr80_1, eq_red70_45, 4, 4),
    (v_vmr80_1, eq_div100_70, 2, 2), (v_vmr80_1, eq_div70_45, 2, 2), (v_vmr80_1, eq_ari, 2, 2),
    (v_vmr80_1, eq_tenue_pen, 2, 2), (v_vmr80_1, eq_tenue_app, 2, 2), (v_vmr80_1, eq_masque, 2, 2),
    (v_vmr80_1, eq_gants, 4, 4), (v_vmr80_1, eq_lunette, 2, 2), (v_vmr80_1, eq_extincteur, 2, 2),
    (v_vmr80_1, eq_extincteur_co2, 1, 1), (v_vmr80_1, eq_hache, 2, 2), (v_vmr80_1, eq_cisailles, 1, 1),
    (v_vmr80_1, eq_pelle, 2, 2), (v_vmr80_1, eq_cle_f, 2, 2), (v_vmr80_1, eq_cle_carree, 2, 2),
    (v_vmr80_1, eq_crepine, 2, 2), (v_vmr80_1, eq_flotteur, 1, 1)
  ON CONFLICT (vehicle_id, equipment_definition_id) DO NOTHING;

  -- Vehicle equipment for VMR 80 N°2 (2 missing)
  INSERT INTO public.vehicle_equipment (vehicle_id, equipment_definition_id, standard_quantity, existing_quantity)
  VALUES
    (v_vmr80_2, eq_tuyau100, 10, 10), (v_vmr80_2, eq_tuyau70, 8, 7), (v_vmr80_2, eq_tuyau45, 6, 6),
    (v_vmr80_2, eq_lance45, 2, 2), (v_vmr80_2, eq_lance70, 2, 2), (v_vmr80_2, eq_lance_mousse70, 1, 1),
    (v_vmr80_2, eq_red100_70, 4, 3), (v_vmr80_2, eq_red70_45, 4, 4), (v_vmr80_2, eq_div100_70, 2, 2),
    (v_vmr80_2, eq_ari, 2, 2), (v_vmr80_2, eq_tenue_pen, 2, 2), (v_vmr80_2, eq_masque, 2, 2),
    (v_vmr80_2, eq_gants, 4, 4), (v_vmr80_2, eq_extincteur, 2, 2), (v_vmr80_2, eq_hache, 2, 2),
    (v_vmr80_2, eq_cle_f, 2, 2), (v_vmr80_2, eq_crepine, 2, 2)
  ON CONFLICT (vehicle_id, equipment_definition_id) DO NOTHING;

  -- Vehicle equipment for VMR 115 N°1 (1 missing)
  INSERT INTO public.vehicle_equipment (vehicle_id, equipment_definition_id, standard_quantity, existing_quantity)
  VALUES
    (v_vmr115_1, eq_tuyau100, 10, 10), (v_vmr115_1, eq_tuyau70, 8, 8), (v_vmr115_1, eq_tuyau45, 6, 6),
    (v_vmr115_1, eq_lance45, 2, 2), (v_vmr115_1, eq_lance70, 2, 2), (v_vmr115_1, eq_lance_mousse70, 1, 1),
    (v_vmr115_1, eq_red100_70, 4, 4), (v_vmr115_1, eq_red70_45, 4, 4), (v_vmr115_1, eq_div100_70, 2, 2),
    (v_vmr115_1, eq_ari, 2, 2), (v_vmr115_1, eq_tenue_pen, 2, 2), (v_vmr115_1, eq_masque, 2, 2),
    (v_vmr115_1, eq_gants, 4, 4), (v_vmr115_1, eq_extincteur, 2, 2), (v_vmr115_1, eq_extincteur_co2, 1, 0),
    (v_vmr115_1, eq_hache, 2, 2), (v_vmr115_1, eq_cle_f, 2, 2), (v_vmr115_1, eq_crepine, 2, 2)
  ON CONFLICT (vehicle_id, equipment_definition_id) DO NOTHING;

  -- Vehicle equipment for VMR 115 N°2 (complete)
  INSERT INTO public.vehicle_equipment (vehicle_id, equipment_definition_id, standard_quantity, existing_quantity)
  VALUES
    (v_vmr115_2, eq_tuyau100, 10, 10), (v_vmr115_2, eq_tuyau70, 8, 8), (v_vmr115_2, eq_tuyau45, 6, 6),
    (v_vmr115_2, eq_lance45, 2, 2), (v_vmr115_2, eq_lance70, 2, 2), (v_vmr115_2, eq_lance_mousse70, 1, 1),
    (v_vmr115_2, eq_red100_70, 4, 4), (v_vmr115_2, eq_ari, 2, 2), (v_vmr115_2, eq_masque, 2, 2),
    (v_vmr115_2, eq_gants, 4, 4), (v_vmr115_2, eq_extincteur, 2, 2), (v_vmr115_2, eq_hache, 2, 2)
  ON CONFLICT (vehicle_id, equipment_definition_id) DO NOTHING;

  -- Vehicle equipment for ISUZU (complete)
  INSERT INTO public.vehicle_equipment (vehicle_id, equipment_definition_id, standard_quantity, existing_quantity)
  VALUES
    (v_isuzu, eq_tuyau70, 4, 4), (v_isuzu, eq_tuyau45, 4, 4), (v_isuzu, eq_lance45, 2, 2),
    (v_isuzu, eq_ari, 2, 2), (v_isuzu, eq_masque, 2, 2), (v_isuzu, eq_gants, 4, 4),
    (v_isuzu, eq_extincteur, 2, 2), (v_isuzu, eq_hache, 1, 1), (v_isuzu, eq_cle_f, 2, 2)
  ON CONFLICT (vehicle_id, equipment_definition_id) DO NOTHING;

  -- Vehicle equipment for ASTRA (5 missing)
  INSERT INTO public.vehicle_equipment (vehicle_id, equipment_definition_id, standard_quantity, existing_quantity)
  VALUES
    (v_astra, eq_tuyau100, 10, 8), (v_astra, eq_tuyau70, 8, 8), (v_astra, eq_tuyau45, 6, 6),
    (v_astra, eq_lance45, 2, 2), (v_astra, eq_lance70, 2, 1), (v_astra, eq_lance_mousse70, 1, 1),
    (v_astra, eq_red100_70, 4, 4), (v_astra, eq_ari, 2, 1), (v_astra, eq_tenue_pen, 2, 2),
    (v_astra, eq_masque, 2, 2), (v_astra, eq_gants, 4, 4), (v_astra, eq_extincteur, 2, 2),
    (v_astra, eq_hache, 2, 1), (v_astra, eq_cle_f, 2, 2), (v_astra, eq_crepine, 2, 2)
  ON CONFLICT (vehicle_id, equipment_definition_id) DO NOTHING;

  -- Maintenance records
  INSERT INTO public.maintenance_records (vehicle_id, maintenance_date, maintenance_type, description, provider, responsible, observation)
  VALUES
    (v_vmr80_2, '2026-07-15', 'Préventive', 'Graissage des parties mécaniques et serrage des boulons', 'Équipe interne RTH', 'Karim Benali', 'RAS — véhicule en bon état général'),
    (v_vmr80_2, '2026-06-10', 'Vidange', 'Vidange huile moteur et changement des filtres (huile, air, carburant)', 'Atelier mécanique Sonatrach', 'Mohamed Hadj', 'Filtres remplacés. Prochaine vidange à 10 000 km.'),
    (v_vmr80_2, '2026-05-22', 'Corrective', 'Démontage et nettoyage du filtre d''émulseur — obstruction partielle détectée', 'Équipe interne RTH', 'Amar Meziane', 'Filtre nettoyé et remis en service. Surveillance recommandée.'),
    (v_vmr115_2, '2026-07-20', 'Préventive', 'Révision complète de la pompe principale', 'Équipe interne RTH', 'Yacine Toumi', 'En cours — retour prévu dans 5 jours'),
    (v_vmr115_2, '2026-04-08', 'Réparation', 'Changement d''un pignon au niveau du mécanisme de transmission de la pompe à eau', 'Prestataire externe — MécaPro Hassi', 'Yacine Toumi', 'Pièce commandée et installée. Test pompe effectué avec succès.'),
    (v_astra, '2026-04-10', 'Corrective', 'Révision moteur complète — véhicule hors service', 'Atelier central Sonatrach', 'Équipe technique', 'Retour prévu fin septembre 2026.'),
    (v_vmr80_1, '2026-07-15', 'Inspection', 'Contrôle technique périodique — inspection complète', 'Centre de contrôle technique Ouargla', 'Inspecteur officiel', 'Certificat valide jusqu''au 23/09/2026')
  ON CONFLICT (id) DO NOTHING;

  -- Alerts
  INSERT INTO public.alerts (vehicle_id, category, severity, title, subtitle, vehicle_name, detail)
  VALUES
    (v_astra, 'insurance', 'critical', 'Assurance expirée', 'Expirée depuis le 31/07/2026', 'ASTRA', 'Renouvellement requis immédiatement.'),
    (v_astra, 'inspection', 'critical', 'Contrôle technique expiré', 'Expiré depuis le 15/06/2026', 'ASTRA', 'Planifier le contrôle technique immédiatement.'),
    (v_vmr115_2, 'inspection', 'warning', 'Contrôle technique proche', 'Expire le 05/08/2026 (dans 7 jours)', 'VMR 115 N°2', 'Planifier le contrôle technique rapidement.'),
    (v_astra, 'equipment', 'critical', '5 équipements manquants', 'Tuyau Ø100 (×2), Lance Ø70 (×1), ARI (×1), Hache (×1)', 'ASTRA', 'Réapprovisionner les équipements manquants.'),
    (v_vmr80_2, 'equipment', 'warning', '2 équipements manquants', 'Tuyau Ø70 (×1), Réduction Ø100-70 (×1)', 'VMR 80 N°2', 'Compléter l''armement du véhicule.'),
    (v_vmr115_1, 'equipment', 'warning', '1 équipement manquant', 'Extincteur CO2 (×1)', 'VMR 115 N°1', NULL),
    (v_vmr115_2, 'maintenance', 'warning', 'Maintenance en cours', 'En maintenance depuis 3 jours', 'VMR 115 N°2', 'Vérifier l''avancement des travaux.'),
    (v_vmr80_2, 'maintenance', 'warning', 'Vidange à prévoir', 'Vidange prévue le 10/06/2026 (dépassée)', 'VMR 80 N°2', 'Planifier la vidange dès que possible.'),
    (v_astra, 'maintenance', 'critical', 'Pompe émulseur en réparation', 'Véhicule indisponible — réparation en cours', 'ASTRA', 'Pompe émulseur en cours de réparation.')
  ON CONFLICT (id) DO NOTHING;

  -- Audit logs (initial seed)
  INSERT INTO public.audit_logs (username, action, description, entity_type)
  VALUES
    ('superadmin', 'vehicle_created', 'Création initiale du parc véhicules RTH', 'vehicle'),
    ('superadmin', 'park_created', 'Création du parc RTH Hassi Messaoud', 'park')
  ON CONFLICT (id) DO NOTHING;

EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Seed data error: %', SQLERRM;
END $$;
