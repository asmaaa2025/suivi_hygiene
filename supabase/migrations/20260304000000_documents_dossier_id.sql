-- Add dossier_id to documents for folder hierarchy
-- Run this only if table documents exists and does not have dossier_id yet
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'documents' AND column_name = 'dossier_id'
  ) THEN
    ALTER TABLE documents
    ADD COLUMN dossier_id UUID REFERENCES documents(id) ON DELETE SET NULL;
  END IF;
END $$;
