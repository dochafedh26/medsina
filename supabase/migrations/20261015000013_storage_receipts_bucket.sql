-- =============================================================================
-- Migration: 20261015000013_storage_receipts_bucket.sql
-- Description: Create Supabase Storage bucket 'receipts' and configure RLS policies
--              for uploading and inspecting subscription payment receipts.
-- =============================================================================

-- 1. CREATE STORAGE BUCKET 'receipts'
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'receipts',
  'receipts',
  true,
  10485760, -- 10 MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg', 'application/pdf'];

-- 2. STORAGE POLICIES (RLS ON storage.objects)

-- A. Allow authenticated users to upload their payment receipt
DROP POLICY IF EXISTS "Allow authenticated users to upload receipts" ON storage.objects;
CREATE POLICY "Allow authenticated users to upload receipts"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'receipts');

-- Also allow anon users to upload receipt if registering during payment
DROP POLICY IF EXISTS "Allow anon users to upload receipts" ON storage.objects;
CREATE POLICY "Allow anon users to upload receipts"
ON storage.objects FOR INSERT
TO anon
WITH CHECK (bucket_id = 'receipts');

-- B. Allow public reading of receipts (public bucket for receipt verification in Admin Console)
DROP POLICY IF EXISTS "Allow public read on receipts" ON storage.objects;
CREATE POLICY "Allow public read on receipts"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'receipts');

-- C. Allow authenticated users to update their uploaded receipts (required for upsert)
DROP POLICY IF EXISTS "Allow authenticated users to update receipts" ON storage.objects;
CREATE POLICY "Allow authenticated users to update receipts"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'receipts')
WITH CHECK (bucket_id = 'receipts');

-- D. Allow admin users to delete receipts if needed
DROP POLICY IF EXISTS "Allow admins to delete receipts" ON storage.objects;
CREATE POLICY "Allow admins to delete receipts"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'receipts' AND
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid() AND profiles.is_admin = true
  )
);
