#!/usr/bin/env bash
# Genera el proyecto de Xcode a partir de brand.json y project.yml.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/sync_brand.py
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Falta XcodeGen. En el Mac: brew install xcodegen"
  exit 1
fi
xcodegen generate
echo "Listo. Abre LufyAprende.xcodeproj y pulsa Run."
