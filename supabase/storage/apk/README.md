# Mise à jour à distance (APK)

## Test

1. **Créer le bucket `apk`** dans Supabase (Storage) et le rendre **public**.
2. **Renommer** `version.json.example` en `version.json` (ou créer un fichier `version.json` avec le même format).
3. **Ajuster** dans `version.json` :
   - `version` / `build` : plus récents que l’app installée (ex. app en 1.0.2+2 → mettre 1.0.3 et 3).
   - `apk_url` : URL directe de l’APK (ex. GitHub Releases : `https://github.com/.../releases/download/v1.0.3/bekkapp_1.0.3.apk`).
4. **Uploader** `version.json` à la racine du bucket `apk`.
   - URL finale attendue : `https://tikfrwuiffzjgxlqvxde.supabase.co/storage/v1/object/public/apk/version.json`
5. Sur l’app (version 1.0.2+2) : **Paramètres → Vérifier les mises à jour** (ou ouvrir le tableau de bord).
   - Si `version.json` est accessible et plus récent → la dialog de mise à jour s’affiche.
   - Sinon → message « Vous avez déjà la dernière version » ou « Impossible de vérifier ».

## Format de version.json

- `version` (string) : ex. "1.0.3"
- `build` (number) : ex. 3
- `apk_url` (string) : URL de téléchargement de l’APK
- `mandatory` (boolean, optionnel) : true = fermeture de l’app impossible sans mettre à jour
- `changelog` (string, optionnel) : texte affiché dans la dialog
- `sha256` (string, optionnel) : hash du fichier (non utilisé pour l’instant)
