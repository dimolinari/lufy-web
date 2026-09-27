#!/usr/bin/env python3
"""Copia el nombre y los identificadores de brand.json a project.yml."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BRAND_PATH = ROOT / "Sources" / "AprendeCore" / "Resources" / "brand.json"
PROJECT_PATH = ROOT / "project.yml"


def sync() -> None:
    brand = json.loads(BRAND_PATH.read_text(encoding="utf-8"))
    text = PROJECT_PATH.read_text(encoding="utf-8")
    replacements = {
        "team": brand["developmentTeam"],
        "ios-bundle": brand["bundleIdentifier"],
        "mac-bundle": brand["macBundleIdentifier"],
        "app-name": f'"{brand["appName"]}"',
    }
    for tag, value in replacements.items():
        pattern = rf"^([ \t]*\S+:[ \t]*).*( # {re.escape(tag)}[ \t]*)$"
        text, count = re.subn(pattern, rf"\1{value}\2", text, count=0, flags=re.M)
        if count == 0:
            raise SystemExit(f"project.yml no tiene una línea marcada con # {tag}")
    PROJECT_PATH.write_text(text, encoding="utf-8")
    print(f"Nombre de la app: {brand['appName']}")
    print(f"Bundle iOS: {brand['bundleIdentifier']}")
    print(f"Bundle Mac: {brand['macBundleIdentifier']}")
    print(f"Team: {brand['developmentTeam']}")


if __name__ == "__main__":
    try:
        sync()
    except OSError as error:
        print(error, file=sys.stderr)
        sys.exit(1)
