#!/usr/bin/env python3
"""Copia el nombre de brand.json a project.yml y los identificadores de partida a signing.xcconfig.

El team real y un bundle id distinto no se escriben aquí. Van en
signing.local.xcconfig, que setup.sh crea y git ignora.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BRAND_PATH = ROOT / "Sources" / "AprendeCore" / "Resources" / "brand.json"
PROJECT_PATH = ROOT / "project.yml"
SIGNING_PATH = ROOT / "signing.xcconfig"
EXAMPLE_PATH = ROOT / "signing.local.example.xcconfig"
PLACEHOLDER_TEAM = "XXXXXXXXXX"

PROJECT_LINES = {
    "team": "DEVELOPMENT_TEAM: $(LUFY_DEVELOPMENT_TEAM) # team",
    "ios-bundle": "PRODUCT_BUNDLE_IDENTIFIER: $(LUFY_IOS_BUNDLE_ID) # ios-bundle",
    "mac-bundle": "PRODUCT_BUNDLE_IDENTIFIER: $(LUFY_MAC_BUNDLE_ID) # mac-bundle",
    "vision-bundle": "PRODUCT_BUNDLE_IDENTIFIER: $(LUFY_VISION_BUNDLE_ID) # vision-bundle",
}


def sync() -> None:
    brand = json.loads(BRAND_PATH.read_text(encoding="utf-8"))
    team = brand["developmentTeam"]
    if team != PLACEHOLDER_TEAM:
        raise SystemExit(
            "brand.json debe conservar el team marcador "
            f"{PLACEHOLDER_TEAM}. El team real va en signing.local.xcconfig."
        )
    text = PROJECT_PATH.read_text(encoding="utf-8")
    app_name = f'"{brand["appName"]}"'
    pattern = r"^([ \t]*\S+:[ \t]*).*( # app-name[ \t]*)$"
    text, count = re.subn(pattern, rf"\1{app_name}\2", text, count=0, flags=re.M)
    if count == 0:
        raise SystemExit("project.yml no tiene una línea marcada con # app-name")
    for tag, expected in PROJECT_LINES.items():
        if expected not in text:
            raise SystemExit(f"project.yml debe contener `{expected}` (# {tag})")
    PROJECT_PATH.write_text(text, encoding="utf-8")
    write_signing(brand)
    write_example(brand)
    print(f"Nombre de la app: {brand['appName']}")
    print(f"Bundle iOS de partida: {brand['bundleIdentifier']}")
    print(f"Bundle Mac de partida: {brand['macBundleIdentifier']}")
    print(f"Bundle visionOS de partida: {brand['visionBundleIdentifier']}")
    print(f"Team de partida: {team}")
    print("El team real, si hace falta, se edita en signing.local.xcconfig.")


def write_signing(brand: dict[str, object]) -> None:
    SIGNING_PATH.write_text(
        "\n".join(
            [
                "// Valores de partida, copiados de brand.json por scripts/sync_brand.py.",
                "// El team de aquí es un marcador. El team real y un bundle id distinto",
                "// van en signing.local.xcconfig, que no se versiona.",
                f"LUFY_DEVELOPMENT_TEAM = {brand['developmentTeam']}",
                f"LUFY_IOS_BUNDLE_ID = {brand['bundleIdentifier']}",
                f"LUFY_MAC_BUNDLE_ID = {brand['macBundleIdentifier']}",
                f"LUFY_VISION_BUNDLE_ID = {brand['visionBundleIdentifier']}",
                '#include? "signing.local.xcconfig"',
                "",
            ]
        ),
        encoding="utf-8",
    )


def write_example(brand: dict[str, object]) -> None:
    EXAMPLE_PATH.write_text(
        "\n".join(
            [
                "// Firma local. setup.sh copia este archivo a signing.local.xcconfig",
                "// si todavía no existe. Ese archivo está en .gitignore: no lo subas.",
                "//",
                "// Sustituye el team marcador por el de tu Apple ID (Personal Team).",
                "// Si com.lufy.aprende ya está ocupado, cambia los tres bundle id",
                "// y vuelve a compilar. No hace falta regenerar el proyecto.",
                f"LUFY_DEVELOPMENT_TEAM = {brand['developmentTeam']}",
                f"LUFY_IOS_BUNDLE_ID = {brand['bundleIdentifier']}",
                f"LUFY_MAC_BUNDLE_ID = {brand['macBundleIdentifier']}",
                f"LUFY_VISION_BUNDLE_ID = {brand['visionBundleIdentifier']}",
                "",
            ]
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    try:
        sync()
    except OSError as error:
        print(error, file=sys.stderr)
        sys.exit(1)
