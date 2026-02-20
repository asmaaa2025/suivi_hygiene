#!/bin/bash
cd "$(dirname "$0")"
echo "=== Pull (rebase) ==="
git pull origin main --rebase
echo ""
echo "=== Push ==="
git push origin main
echo ""
echo "Terminé."
