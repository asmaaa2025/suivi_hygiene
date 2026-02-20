-- Bucket nc-files pour les pièces jointes des non-conformités
-- RLS policies pour autoriser l'upload des photos/documents

-- Créer le bucket si nécessaire
INSERT INTO storage.buckets (id, name, public)
VALUES ('nc-files', 'nc-files', false)
ON CONFLICT (id) DO NOTHING;

-- Politique: les utilisateurs authentifiés peuvent uploader dans nc-files
CREATE POLICY "nc-files: authenticated insert"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'nc-files');

-- Politique: les utilisateurs authentifiés peuvent lire les fichiers
CREATE POLICY "nc-files: authenticated select"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'nc-files');

-- Politique: les utilisateurs authentifiés peuvent modifier
CREATE POLICY "nc-files: authenticated update"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'nc-files')
WITH CHECK (bucket_id = 'nc-files');

-- Politique: les utilisateurs authentifiés peuvent supprimer
CREATE POLICY "nc-files: authenticated delete"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'nc-files');
