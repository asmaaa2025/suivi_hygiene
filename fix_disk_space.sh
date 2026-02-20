#!/bin/bash
# Script pour libérer de l'espace disque et corriger "No space left on device"
# À exécuter depuis la racine du projet : bash fix_disk_space.sh

set -e
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo "=== 1. Vérification de l'espace disque ==="
df -h /

echo ""
echo "=== 2. Arrêt des processus Gradle/Java (libère les locks) ==="
pkill -f 'GradleDaemon' 2>/dev/null || true
pkill -f '.*gradle.*' 2>/dev/null || true
sleep 2
./gradlew --stop 2>/dev/null || true

echo ""
echo "=== 3. Suppression des caches Gradle du projet et Flutter SDK ==="
rm -rf android/.gradle 2>/dev/null || true
rm -rf .gradle 2>/dev/null || true
rm -rf "$HOME/development/flutter/packages/flutter_tools/gradle/.gradle" 2>/dev/null || true

echo ""
echo "=== 4. Nettoyage Flutter ==="
flutter clean

echo ""
echo "=== 5. Suppression des dossiers build du projet ==="
rm -rf build
rm -rf .dart_tool
rm -rf android/app/build
rm -rf android/build

echo ""
echo "=== 6. Nettoyage du cache Gradle global (~/.gradle) ==="
rm -rf ~/.gradle/caches/transforms-* 2>/dev/null || true
rm -rf ~/.gradle/caches/build-cache-* 2>/dev/null || true
rm -rf ~/.gradle/caches/8.*/executionHistory 2>/dev/null || true
rm -rf ~/.gradle/caches/8.*/md-supplier 2>/dev/null || true
rm -rf ~/.gradle/caches/8.*/md-rule 2>/dev/null || true
rm -rf ~/.gradle/caches/8.*/buildOutputCleanup 2>/dev/null || true
echo "Cache Gradle global nettoyé."

if [ "$1" = "--full" ]; then
  echo "Nettoyage complet (--full)..."
  dart pub cache clean 2>/dev/null || true
  rm -rf ~/.gradle/caches 2>/dev/null || true
fi

echo ""
echo "=== 7. Espace libéré - état actuel ==="
df -h /

echo ""
echo "=== 8. Récupération des dépendances ==="
flutter pub get

echo ""
echo "=== Terminé. Lancez : flutter run ==="
