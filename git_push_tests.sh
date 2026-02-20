#!/bin/bash
# Push les tests sur git

cd "$(dirname "$0")"

echo "=== Ajout des fichiers de tests ==="
git add test/
git add pubspec.yaml
git add .github/workflows/ci.yml
git add TESTING_STRATEGY.md
git add integration_test/
git add analysis_options.yaml

echo ""
echo "=== Statut ==="
git status --short

echo ""
echo "=== Commit ==="
git commit -m "test: stratégie de tests HACCPilot

- Unit tests: TextSanitizer, température, appareil, personnel
- Unit tests: AlertEngine, modèles alertes
- Unit tests: ComplianceService
- Widget tests: EmptyState, SectionCard
- CI: .github/workflows/ci.yml (analyse, tests, couverture)
- Dépendances: mocktail, integration_test"

echo ""
echo "=== Push ==="
git push origin

echo ""
echo "Terminé."
