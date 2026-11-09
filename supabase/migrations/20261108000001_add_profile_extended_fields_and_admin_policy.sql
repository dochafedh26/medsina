-- Migration: Add extended profile fields and admin access policy on public.profiles
-- Date: 2026-11-08

-- 1. Add missing profile columns to public.profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS study_year integer,
  ADD COLUMN IF NOT EXISTS bio text,
  ADD COLUMN IF NOT EXISTS phone text,
  ADD COLUMN IF NOT EXISTS wilaya text,
  ADD COLUMN IF NOT EXISTS residency_target_year text;

-- 2. Helpful indexes
CREATE INDEX IF NOT EXISTS idx_profiles_wilaya ON public.profiles(wilaya);
CREATE INDEX IF NOT EXISTS idx_profiles_study_year ON public.profiles(study_year);
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON public.profiles(phone);

-- 3. Admin RLS Policies for Profiles
-- Allow admins (is_admin = true) to read all profiles
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
CREATE POLICY "Admins can view all profiles" ON public.profiles
  FOR SELECT
  USING (
    auth.uid() = id 
    OR EXISTS (
      SELECT 1 FROM public.profiles admin_p 
      WHERE admin_p.id = auth.uid() AND admin_p.is_admin IS TRUE
    )
  );

-- Allow admins to update all profiles (for administrative corrections)
DROP POLICY IF EXISTS "Admins can update all profiles" ON public.profiles;
CREATE POLICY "Admins can update all profiles" ON public.profiles
  FOR UPDATE
  USING (
    auth.uid() = id 
    OR EXISTS (
      SELECT 1 FROM public.profiles admin_p 
      WHERE admin_p.id = auth.uid() AND admin_p.is_admin IS TRUE
    )
  );

-- 4. Replace admin_list_users to return extended profile columns
DROP FUNCTION IF EXISTS public.admin_list_users();
DROP FUNCTION IF EXISTS public.admin_list_users;

CREATE OR REPLACE FUNCTION public.admin_list_users()
RETURNS TABLE (
  id uuid,
  email text,
  full_name text,
  medical_role text,
  faculty text,
  tier text,
  status text,
  expires_at timestamptz,
  is_admin boolean,
  is_banned boolean,
  ban_reason text,
  rejected_payments_count integer,
  created_at timestamptz,
  study_year integer,
  bio text,
  phone text,
  wilaya text,
  residency_target_year text,
  avatar_url text,
  updated_at timestamptz
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.email,
    p.full_name,
    p.medical_role,
    p.faculty,
    coalesce(s.tier, 'free') as tier,
    case 
      when p.is_banned is true then 'suspended'
      when s.status is not null then s.status
      else 'active'
    end as status,
    s.expires_at,
    coalesce(p.is_admin, false) as is_admin,
    coalesce(p.is_banned, false) as is_banned,
    p.ban_reason,
    coalesce(p.rejected_payments_count, 0) as rejected_payments_count,
    p.created_at,
    p.study_year,
    p.bio,
    p.phone,
    p.wilaya,
    p.residency_target_year,
    p.avatar_url,
    p.updated_at
  FROM public.profiles p
  LEFT JOIN public.subscriptions s ON s.user_id = p.id
  ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
