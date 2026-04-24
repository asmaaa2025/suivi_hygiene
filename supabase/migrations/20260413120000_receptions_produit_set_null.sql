-- Same as 29_receptions_produit_on_delete_set_null.sql (Supabase CLI)

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT c.conname
    FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    WHERE t.relname = 'receptions'
      AND t.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
      AND c.contype = 'f'
      AND pg_get_constraintdef(c.oid) LIKE '%produit_id%'
      AND pg_get_constraintdef(c.oid) LIKE '%produits%'
  LOOP
    EXECUTE format('ALTER TABLE public.receptions DROP CONSTRAINT IF EXISTS %I', r.conname);
  END LOOP;
END $$;

ALTER TABLE public.receptions
  ADD CONSTRAINT receptions_produit_id_fkey
  FOREIGN KEY (produit_id)
  REFERENCES public.produits(id)
  ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.trg_snapshot_produit_nom_before_produit_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.receptions r
  SET
    produit = COALESCE(NULLIF(TRIM(r.produit), ''), OLD.nom),
    article = COALESCE(NULLIF(TRIM(r.article), ''), OLD.nom)
  WHERE r.produit_id = OLD.id;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS snapshot_produit_nom_before_produit_delete ON public.produits;
CREATE TRIGGER snapshot_produit_nom_before_produit_delete
  BEFORE DELETE ON public.produits
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_snapshot_produit_nom_before_produit_delete();
