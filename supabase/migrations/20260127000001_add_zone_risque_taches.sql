-- Zone à risque pour les tâches de nettoyage (PMS - classification des locaux)
ALTER TABLE taches_nettoyage ADD COLUMN IF NOT EXISTS zone_risque TEXT;
