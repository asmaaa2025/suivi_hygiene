# Edge Functions Supabase

## create-haccp-user

Permet à l'administrateur de créer des comptes utilisateurs HACCPilot depuis l'app.

### Déploiement

```bash
# Depuis la racine du projet
supabase functions deploy create-haccp-user
```

### Prérequis

- Supabase CLI installé (`npm i -g supabase`)
- Projet Supabase lié (`supabase link`)

La fonction utilise `SUPABASE_SERVICE_ROLE_KEY` (fourni automatiquement par Supabase) pour créer les utilisateurs via l'API admin.
