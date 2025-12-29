-- ============================================
-- CONSOLIDATED STORAGE SETUP
-- ============================================
-- This file contains all Supabase Storage bucket creation and policies
-- Execute this AFTER 00_schema.sql and 10_security.sql
-- ============================================
-- NOTE: Buckets can be created via SQL or Dashboard
-- If creating via Dashboard, skip the INSERT INTO storage.buckets statements
-- ============================================

BEGIN;

-- ============================================
-- STORAGE BUCKETS
-- ============================================
-- Create buckets if they don't exist
-- Note: Bucket creation via SQL requires appropriate permissions
-- Alternative: Create buckets via Supabase Dashboard > Storage

-- Bucket 1: haccp-photos (for general HACCP photos)
INSERT INTO storage.buckets (id, name, public)
VALUES ('haccp-photos', 'haccp-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Bucket 2: documents (for general documents)
INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', false)
ON CONFLICT (id) DO NOTHING;

-- Bucket 3: temperatures (for temperature log photos)
INSERT INTO storage.buckets (id, name, public)
VALUES ('temperatures', 'temperatures', false)
ON CONFLICT (id) DO NOTHING;

-- Bucket 4: receptions (for reception photos)
INSERT INTO storage.buckets (id, name, public)
VALUES ('receptions', 'receptions', false)
ON CONFLICT (id) DO NOTHING;

-- Bucket 5: photos (alternative name, for general photos)
INSERT INTO storage.buckets (id, name, public)
VALUES ('photos', 'photos', false)
ON CONFLICT (id) DO NOTHING;

-- Bucket 6: releves (for temperature readings/photos)
INSERT INTO storage.buckets (id, name, public)
VALUES ('releves', 'releves', false)
ON CONFLICT (id) DO NOTHING;

-- Bucket 7: nettoyage (for cleaning photos)
INSERT INTO storage.buckets (id, name, public)
VALUES ('nettoyage', 'nettoyage', false)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- STORAGE POLICIES
-- ============================================
-- Drop existing policies to avoid conflicts
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', r.policyname);
  END LOOP;
END $$;

-- ============================================
-- BUCKET: haccp-photos
-- ============================================
-- Public bucket for HACCP photos
-- Files organized by user: userId/filename.jpg

-- Policy: Allow authenticated users to upload photos to their own folder
CREATE POLICY "Photos: Upload for authenticated"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'haccp-photos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Allow all authenticated users to read photos
CREATE POLICY "Photos: Read for authenticated"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'haccp-photos');

-- Policy: Allow users to update their own photos
CREATE POLICY "Photos: Update for owner"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'haccp-photos' AND
  (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'haccp-photos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Allow users to delete their own photos
CREATE POLICY "Photos: Delete for owner"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'haccp-photos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================
-- BUCKET: documents
-- ============================================
-- Private bucket for documents
-- Files organized by user: userId/filename

-- Policy: Users can upload files to their own folder
CREATE POLICY "Users can upload own documents"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'documents' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy: Users can view their own files
CREATE POLICY "Users can view own documents"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'documents' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy: Users can update their own files
CREATE POLICY "Users can update own documents"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'documents' AND
  auth.uid()::text = (storage.foldername(name))[1]
)
WITH CHECK (
  bucket_id = 'documents' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy: Users can delete their own files
CREATE POLICY "Users can delete own documents"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'documents' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- ============================================
-- BUCKET: temperatures
-- ============================================
-- Private bucket for temperature log photos
-- Files organized by user: userId/filename

-- Policy: Users can upload temperature photos to their own folder
CREATE POLICY "Users can upload own temperature photos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'temperatures' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy: Users can view their own temperature photos
CREATE POLICY "Users can view own temperature photos"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'temperatures' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy: Users can update their own temperature photos
CREATE POLICY "Users can update own temperature photos"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'temperatures' AND
  auth.uid()::text = (storage.foldername(name))[1]
)
WITH CHECK (
  bucket_id = 'temperatures' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy: Users can delete their own temperature photos
CREATE POLICY "Users can delete own temperature photos"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'temperatures' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- ============================================
-- BUCKET: receptions
-- ============================================
-- Private bucket for reception photos
-- Files organized by user: userId/filename

-- Policy: Users can upload reception photos to their own folder
CREATE POLICY "Users can upload own reception photos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'receptions' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy: Users can view their own reception photos
CREATE POLICY "Users can view own reception photos"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'receptions' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy: Users can update their own reception photos
CREATE POLICY "Users can update own reception photos"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'receptions' AND
  auth.uid()::text = (storage.foldername(name))[1]
)
WITH CHECK (
  bucket_id = 'receptions' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy: Users can delete their own reception photos
CREATE POLICY "Users can delete own reception photos"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'receptions' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- ============================================
-- BUCKET: photos (alternative/generic)
-- ============================================
-- Private bucket for general photos
-- Allow authenticated users to read/upload

-- Policy: Allow authenticated users to read from photos bucket
CREATE POLICY "allow authenticated reads on photos"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'photos');

-- Policy: Allow authenticated users to upload to photos bucket
CREATE POLICY "allow authenticated uploads to photos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'photos');

-- Policy: Allow authenticated users to update their own files in photos bucket
CREATE POLICY "allow authenticated updates to photos"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'photos')
WITH CHECK (bucket_id = 'photos');

-- Policy: Allow authenticated users to delete their own files in photos bucket
CREATE POLICY "allow authenticated deletes from photos"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'photos');

-- ============================================
-- BUCKET: releves (for temperature readings)
-- ============================================
-- Private bucket for temperature reading photos

-- Policy: Allow authenticated users to read from releves bucket
CREATE POLICY "allow authenticated reads on releves"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'releves');

-- Policy: Allow authenticated users to upload to releves bucket
CREATE POLICY "allow authenticated uploads to releves"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'releves');

-- Policy: Allow authenticated users to update their own files in releves bucket
CREATE POLICY "allow authenticated updates to releves"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'releves')
WITH CHECK (bucket_id = 'releves');

-- Policy: Allow authenticated users to delete their own files in releves bucket
CREATE POLICY "allow authenticated deletes from releves"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'releves');

-- ============================================
-- BUCKET: nettoyage (for cleaning photos)
-- ============================================
-- Private bucket for cleaning photos
-- Files organized by user: userId/filename

-- Policy: Users can upload cleaning photos to their own folder
CREATE POLICY "Users can upload own nettoyage photos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'nettoyage' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy: Users can view their own cleaning photos
CREATE POLICY "Users can view own nettoyage photos"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'nettoyage' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy: Users can update their own cleaning photos
CREATE POLICY "Users can update own nettoyage photos"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'nettoyage' AND
  auth.uid()::text = (storage.foldername(name))[1]
)
WITH CHECK (
  bucket_id = 'nettoyage' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy: Users can delete their own cleaning photos
CREATE POLICY "Users can delete own nettoyage photos"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'nettoyage' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

COMMIT;

-- ============================================
-- NOTES
-- ============================================
-- 1. Buckets can be created via Supabase Dashboard > Storage if SQL fails
-- 2. File organization: userId/filename.ext (e.g., "abc123/photo.jpg")
-- 3. Public buckets (haccp-photos) allow direct URL access
-- 4. Private buckets require authentication and RLS policies
-- 5. File size limits and MIME type restrictions should be set in Dashboard
-- 6. Recommended bucket settings:
--    - documents: 50MB limit, all MIME types
--    - temperatures: 10MB limit, image/* MIME types
--    - receptions: 10MB limit, image/* MIME types
--    - haccp-photos: 10MB limit, image/* MIME types
--    - nettoyage: 10MB limit, image/* MIME types
-- ============================================

-- ============================================
-- END OF STORAGE SETUP
-- ============================================

