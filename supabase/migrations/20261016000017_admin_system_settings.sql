-- Migration: 20261016000017_admin_system_settings.sql
-- Description: Table sécurisée pour stocker les paramètres d'administration (PAT GitHub, Dépôt, webhooks...)
-- Sécurité: Protégée strictement par RLS pour les administrateurs (profiles.is_admin = true) et service_role.

CREATE TABLE IF NOT EXISTS public.admin_system_settings (
    setting_key TEXT PRIMARY KEY,
    setting_value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Index pour recherche rapide (la clé primaire est déjà indexée par défaut)
CREATE INDEX IF NOT EXISTS idx_admin_system_settings_updated 
ON public.admin_system_settings (updated_at DESC);

-- Activation impérative de RLS
ALTER TABLE public.admin_system_settings ENABLE ROW LEVEL SECURITY;

-- Suppression des anciennes règles si ré-exécution
DROP POLICY IF EXISTS "Admin read system settings" ON public.admin_system_settings;
DROP POLICY IF EXISTS "Admin insert system settings" ON public.admin_system_settings;
DROP POLICY IF EXISTS "Admin update system settings" ON public.admin_system_settings;
DROP POLICY IF EXISTS "Admin delete system settings" ON public.admin_system_settings;

-- 1. Lecture: UNIQUEMENT Administrateurs ou service_role
CREATE POLICY "Admin read system settings" 
ON public.admin_system_settings
FOR SELECT 
USING (
    auth.role() = 'service_role' OR
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid() AND (profiles.is_admin = TRUE OR profiles.medical_role = 'Admin')
    )
);

-- 2. Insertion: UNIQUEMENT Administrateurs ou service_role
CREATE POLICY "Admin insert system settings" 
ON public.admin_system_settings
FOR INSERT 
WITH CHECK (
    auth.role() = 'service_role' OR
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid() AND (profiles.is_admin = TRUE OR profiles.medical_role = 'Admin')
    )
);

-- 3. Mise à jour: UNIQUEMENT Administrateurs ou service_role
CREATE POLICY "Admin update system settings" 
ON public.admin_system_settings
FOR UPDATE 
USING (
    auth.role() = 'service_role' OR
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid() AND (profiles.is_admin = TRUE OR profiles.medical_role = 'Admin')
    )
)
WITH CHECK (
    auth.role() = 'service_role' OR
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid() AND (profiles.is_admin = TRUE OR profiles.medical_role = 'Admin')
    )
);

-- 4. Suppression: UNIQUEMENT Administrateurs ou service_role
CREATE POLICY "Admin delete system settings" 
ON public.admin_system_settings
FOR DELETE 
USING (
    auth.role() = 'service_role' OR
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE profiles.id = auth.uid() AND (profiles.is_admin = TRUE OR profiles.medical_role = 'Admin')
    )
);

-- Privilèges
GRANT ALL ON TABLE public.admin_system_settings TO authenticated;
GRANT ALL ON TABLE public.admin_system_settings TO service_role;

-- Fonctions RPC sécurisées (SECURITY DEFINER avec search_path fixé)
CREATE OR REPLACE FUNCTION public.get_admin_setting(p_key TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_is_admin BOOLEAN := FALSE;
    v_val TEXT;
BEGIN
    SELECT (is_admin = TRUE OR medical_role = 'Admin') INTO v_is_admin
    FROM public.profiles
    WHERE id = auth.uid();

    IF v_is_admin IS NOT TRUE AND auth.role() <> 'service_role' THEN
        RAISE EXCEPTION 'Accès refusé : privilèges administrateur requis.';
    END IF;

    SELECT setting_value INTO v_val
    FROM public.admin_system_settings
    WHERE setting_key = p_key;

    RETURN v_val;
END;
$$;

CREATE OR REPLACE FUNCTION public.save_admin_setting(p_key TEXT, p_value TEXT, p_description TEXT DEFAULT NULL)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_is_admin BOOLEAN := FALSE;
BEGIN
    SELECT (is_admin = TRUE OR medical_role = 'Admin') INTO v_is_admin
    FROM public.profiles
    WHERE id = auth.uid();

    IF v_is_admin IS NOT TRUE AND auth.role() <> 'service_role' THEN
        RAISE EXCEPTION 'Accès refusé : privilèges administrateur requis.';
    END IF;

    INSERT INTO public.admin_system_settings (setting_key, setting_value, description, updated_at, updated_by)
    VALUES (p_key, p_value, p_description, timezone('utc'::text, now()), auth.uid())
    ON CONFLICT (setting_key) DO UPDATE
    SET setting_value = EXCLUDED.setting_value,
        description = COALESCE(EXCLUDED.description, admin_system_settings.description),
        updated_at = timezone('utc'::text, now()),
        updated_by = auth.uid();

    RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_admin_setting(TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.save_admin_setting(TEXT, TEXT, TEXT) TO authenticated, service_role;

