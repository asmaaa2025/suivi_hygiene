#!/bin/bash
# Script pour commit et push sur git avec commentaires détaillés

cd "$(dirname "$0")"

echo "=== Statut actuel ==="
git status

echo ""
read -p "Continuer avec les commits ? (o/n) " rep
[ "$rep" != "o" ] && exit 0

# Commit 1: NC - brouillons + export PDF
git add lib/features/haccp/pages/nc_wizard/steps/nc_wizard_review.dart \
        lib/services/nc_pdf_export_service.dart \
        lib/data/repositories/nc_repository.dart \
        lib/features/haccp/pages/nc_wizard/steps/nc_wizard_success.dart 2>/dev/null
if ! git diff --cached --quiet 2>/dev/null; then
  git commit -m "fix(nc): suppression brouillon après création + photos dans export PDF

- Retire le brouillon après création d'une NC (clearDrafts)
- Affiche les photos dans l'export PDF des fiches NC au lieu de 'pièce jointe'
- Téléchargement via Supabase Storage pour bucket privé nc-files"
  echo "✓ Commit NC"
fi

# Commit 2: Classeur hebdomadaire
git add lib/features/haccp/pages/synthese_hebdomadaire_page.dart 2>/dev/null
if ! git diff --cached --quiet 2>/dev/null; then
  git commit -m "feat(haccp): classeur hebdomadaire - sélection dates et presets

- Choix date début / date fin
- Presets: Semaine courante, 7j, 14j, 1 mois, +7 jours
- Export PDF sur la période sélectionnée"
  echo "✓ Commit classeur"
fi

# Commit 3: Comptes HACCPilot
git add lib/features/admin/pages/rh_hub_page.dart \
        lib/features/admin/pages/haccp_user_accounts_page.dart \
        lib/features/admin/pages/haccp_user_account_form_page.dart \
        lib/data/models/haccp_user_account.dart \
        lib/data/repositories/haccp_user_account_repository.dart \
        lib/core/router/app_router.dart \
        supabase/migrations/20260127200000_create_haccp_user_accounts.sql \
        supabase/functions/create-haccp-user/ \
        supabase/functions/README.md 2>/dev/null
if ! git diff --cached --quiet 2>/dev/null; then
  git commit -m "feat(rh): comptes utilisateurs HACCPilot (distinct du registre personnel)

- Nouveau tile Comptes HACCPilot dans la section RH
- Page liste + formulaire création (email, mot de passe)
- Table haccp_user_accounts + Edge Function create-haccp-user
- Lien optionnel vers registre personnel"
  echo "✓ Commit comptes HACCPilot"
fi

# Commit 4: Script fix disque
git add fix_disk_space.sh 2>/dev/null
if ! git diff --cached --quiet 2>/dev/null; then
  git commit -m "chore: amélioration script fix_disk_space

- Nettoyage verrous Gradle et caches executionHistory
- Support erreurs No space left / lock Gradle"
  echo "✓ Commit fix_disk_space"
fi

# Commit 5: Fichiers restants
git add -A
if ! git diff --cached --quiet 2>/dev/null; then
  git status --short
  git commit -m "chore: autres modifications"
  echo "✓ Commit divers"
fi

echo ""
echo "=== Push ==="
git push origin

echo ""
echo "=== Terminé ==="
