#!/usr/bin/env bash
# Genera el proyecto de Xcode a partir de brand.json, project.yml y la firma local.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/sync_brand.py
if [[ ! -f signing.local.xcconfig ]]; then
  cp signing.local.example.xcconfig signing.local.xcconfig
  echo "Se creó signing.local.xcconfig. Ahí va el team y, si hace falta, otro bundle id. No lo subas."
fi
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Falta XcodeGen. En el Mac: brew install xcodegen"
  exit 1
fi
xcodegen generate
echo "Listo. Abre LufyAprende.xcodeproj y pulsa Run."
