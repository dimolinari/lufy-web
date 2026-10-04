#!/usr/bin/env python3
"""Simplifica los límites ADM1 de geoBoundaries (CC0) a un JSON pequeño.

El archivo de entrada no se versiona. Se descarga aparte, por ejemplo el
GeoJSON simplificado de gbOpen ECU ADM1. Este script no llama a la red.

No incluye elevación. Los mosaicos SRTM públicos pesan decenas de megabytes
por tesela; el grosor 3D lo pone la app y es uniforme.
"""

from __future__ import annotations

import json
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT / "Sources" / "AprendeCore" / "Resources" / "Spatial" / "provincias-limites.json"

REGIONS = {
    "Esmeraldas": "Costa",
    "Manabi": "Costa",
    "Santo Domingo de los Tsáchilas": "Costa",
    "Los Ríos": "Costa",
    "Guayas": "Costa",
    "Santa Elena": "Costa",
    "El Oro": "Costa",
    "Carchi": "Sierra",
    "Imbabura": "Sierra",
    "Pichincha": "Sierra",
    "Cotopaxi": "Sierra",
    "Tungurahua": "Sierra",
    "Bolívar": "Sierra",
    "Chimborazo": "Sierra",
    "Cañar": "Sierra",
    "Azuay": "Sierra",
    "Loja": "Sierra",
    "Sucumbios": "Amazonía",
    "Napo": "Amazonía",
    "Orellana": "Amazonía",
    "Pastaza": "Amazonía",
    "Morona Santiago": "Amazonía",
    "Zamora Chinchipe": "Amazonía",
    "Galápagos": "Región Insular",
}

DISPLAY = {
    "Manabi": "Manabí",
    "Sucumbios": "Sucumbíos",
}


def fold(text: str) -> str:
    normalized = unicodedata.normalize("NFD", text)
    stripped = "".join(ch for ch in normalized if unicodedata.category(ch) != "Mn")
    return stripped.lower()


def slug(name: str) -> str:
    cleaned = []
    for ch in fold(name):
        if ch.isalnum():
            cleaned.append(ch)
        elif ch in " -_":
            cleaned.append("-")
    raw = "".join(cleaned)
    while "--" in raw:
        raw = raw.replace("--", "-")
    return raw.strip("-")


def signed_area(points: list[tuple[float, float]]) -> float:
    total = 0.0
    count = len(points)
    for index in range(count):
        x1, y1 = points[index]
        x2, y2 = points[(index + 1) % count]
        total += x1 * y2 - x2 * y1
    return total / 2


def cross(a, b, c) -> float:
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def perpendicular_distance(point, start, end) -> float:
    dx = end[0] - start[0]
    dy = end[1] - start[1]
    length = (dx * dx + dy * dy) ** 0.5
    if length == 0:
        return ((point[0] - start[0]) ** 2 + (point[1] - start[1]) ** 2) ** 0.5
    return abs(dy * point[0] - dx * point[1] + end[0] * start[1] - end[1] * start[0]) / length


def douglas_peucker(points: list[tuple[float, float]], epsilon: float) -> list[tuple[float, float]]:
    if len(points) < 3:
        return points[:]
    start = points[0]
    end = points[-1]
    index = 0
    farthest = 0.0
    for cursor in range(1, len(points) - 1):
        distance = perpendicular_distance(points[cursor], start, end)
        if distance > farthest:
            farthest = distance
            index = cursor
    if farthest > epsilon:
        left = douglas_peucker(points[: index + 1], epsilon)
        right = douglas_peucker(points[index:], epsilon)
        return left[:-1] + right
    return [start, end]


def open_ring(ring: list[list[float]]) -> list[tuple[float, float]]:
    points = [(float(pair[0]), float(pair[1])) for pair in ring]
    if len(points) >= 2 and points[0] == points[-1]:
        points = points[:-1]
    deduped = []
    for point in points:
        if not deduped or abs(point[0] - deduped[-1][0]) > 1e-8 or abs(point[1] - deduped[-1][1]) > 1e-8:
            deduped.append(point)
    return deduped


def drop_collinear(points: list[tuple[float, float]]) -> list[tuple[float, float]]:
    if len(points) < 4:
        return points
    kept = []
    count = len(points)
    for index in range(count):
        previous = points[(index - 1) % count]
        current = points[index]
        nxt = points[(index + 1) % count]
        if abs(cross(previous, current, nxt)) > 1e-12:
            kept.append(current)
    return kept if len(kept) >= 3 else points


def segments_cross(a, b, c, d) -> bool:
    d1 = cross(a, b, c)
    d2 = cross(a, b, d)
    d3 = cross(c, d, a)
    d4 = cross(c, d, b)
    return d1 * d2 < 0 and d3 * d4 < 0


def self_intersects(points: list[tuple[float, float]]) -> bool:
    count = len(points)
    if count < 4:
        return False
    for i in range(count):
        a = points[i]
        b = points[(i + 1) % count]
        for j in range(i + 1, count):
            if abs(i - j) <= 1 or (i == 0 and j == count - 1):
                continue
            c = points[j]
            d = points[(j + 1) % count]
            if j == i or (j + 1) % count == i or (i + 1) % count == j:
                continue
            if segments_cross(a, b, c, d):
                return True
    return False


def strictly_inside(point, a, b, c) -> bool:
    c1 = cross(a, b, point)
    c2 = cross(b, c, point)
    c3 = cross(c, a, point)
    return c1 > 1e-10 and c2 > 1e-10 and c3 > 1e-10


def triangulate(points: list[tuple[float, float]]) -> list[tuple[int, int, int]] | None:
    if len(points) < 3:
        return None
    working = list(range(len(points)))
    if signed_area(points) < 0:
        working.reverse()
    triangles: list[tuple[int, int, int]] = []
    guard = 0
    while len(working) > 3 and guard < 20000:
        guard += 1
        count = len(working)
        found = False
        for cursor in range(count):
            i0 = working[(cursor - 1) % count]
            i1 = working[cursor]
            i2 = working[(cursor + 1) % count]
            a, b, c = points[i0], points[i1], points[i2]
            if cross(a, b, c) <= 1e-12:
                continue
            blocked = False
            for other in working:
                if other in (i0, i1, i2):
                    continue
                if strictly_inside(points[other], a, b, c):
                    blocked = True
                    break
            if blocked:
                continue
            triangles.append((i0, i1, i2))
            del working[cursor]
            found = True
            break
        if not found:
            return None
    if len(working) == 3:
        triangles.append((working[0], working[1], working[2]))
    return triangles


def simplify_ring(points: list[tuple[float, float]], epsilon: float, cap: int) -> list[tuple[float, float]]:
    current = points
    step = epsilon
    for _ in range(8):
        closed = current + [current[0]]
        reduced = douglas_peucker(closed, step)
        if reduced and reduced[0] == reduced[-1]:
            reduced = reduced[:-1]
        reduced = drop_collinear(reduced)
        if len(reduced) <= cap and len(reduced) >= 3 and not self_intersects(reduced) and triangulate(reduced):
            return reduced
        step *= 1.35
    # Último recurso: el anillo ya simplificado aunque sea más largo, si triangula.
    closed = points + [points[0]]
    reduced = drop_collinear(douglas_peucker(closed, epsilon * 2))
    if reduced and reduced[0] == reduced[-1]:
        reduced = reduced[:-1]
    return reduced


def polygons_of(geometry: dict) -> list[list[list[tuple[float, float]]]]:
    kind = geometry["type"]
    coords = geometry["coordinates"]
    if kind == "Polygon":
        return [[open_ring(ring) for ring in coords if open_ring(ring)]]
    if kind == "MultiPolygon":
        output = []
        for polygon in coords:
            rings = [open_ring(ring) for ring in polygon if open_ring(ring)]
            if rings:
                output.append(rings)
        return output
    return []


def build(source: Path, destination: Path) -> None:
    collection = json.loads(source.read_text(encoding="utf-8"))
    provinces = []
    for feature in collection["features"]:
        props = feature["properties"]
        raw_name = props["shapeName"]
        if raw_name not in REGIONS:
            raise SystemExit(f"Provincia sin región: {raw_name}")
        display = DISPLAY.get(raw_name, raw_name)
        inset = raw_name == "Galápagos"
        epsilon = 0.02 if inset else 0.035
        cap = 48 if inset else 70
        candidates = []
        for polygon in polygons_of(feature["geometry"]):
            outer = polygon[0]
            area = abs(signed_area(outer))
            if area <= 0 or len(outer) < 3:
                continue
            candidates.append((area, outer))
        candidates.sort(key=lambda item: item[0], reverse=True)
        if not candidates:
            raise SystemExit(f"Sin anillo: {raw_name}")
        largest = candidates[0][0]
        keep_limit = 6 if inset else 2
        kept = []
        for area, ring in candidates:
            if area < largest * (0.04 if inset else 0.08):
                continue
            simplified = simplify_ring(ring, epsilon, cap)
            if len(simplified) < 3:
                continue
            if triangulate(simplified) is None:
                raise SystemExit(f"No triangula: {display}")
            if self_intersects(simplified):
                raise SystemExit(f"El contorno se cruza: {display}")
            kept.append([[round(lon, 4), round(lat, 4)] for lon, lat in simplified])
            if len(kept) >= keep_limit:
                break
        if not kept:
            raise SystemExit(f"Sin contorno útil: {display}")
        provinces.append(
            {
                "id": slug(display),
                "name": display,
                "region": REGIONS[raw_name],
                "inset": inset,
                "rings": kept,
            }
        )
    provinces.sort(key=lambda item: item["id"])
    if len(provinces) != 24:
        raise SystemExit(f"Se esperaban 24 provincias y hay {len(provinces)}")
    document = {
        "schema": "lufy.limites.v1",
        "license": "CC0 1.0 Universal",
        "attribution": (
            "geoBoundaries (www.geoboundaries.org), gbOpen ECU ADM1, licencia CC0 1.0. "
            "Publicación 9469f09. Consultado el 27 de septiembre de 2026. "
            "La ficha de geoBoundaries nombra como fuente a geoBoundaries y Wikimedia Commons."
        ),
        "elevationIncluded": False,
        "elevationNote": (
            "No hay modelo de elevación. El grosor es el mismo en todas las provincias "
            "para poder tocarlas. No son metros de altitud. Las teselas SRTM de dominio "
            "público pesan unos 18 MB cada una y no se incluyeron."
        ),
        "insetNote": (
            "Galápagos está en un recuadro al oeste del continente. No guarda la distancia "
            "real, de cerca de mil kilómetros."
        ),
        "regionNote": (
            "La región sigue el agrupamiento de la lección de geografía: Costa, Sierra, "
            "Amazonía y Región Insular. Santo Domingo de los Tsáchilas va con la Costa. "
            "Es una clasificación, no una altitud."
        ),
        "provinces": provinces,
    }
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(document, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    points = sum(len(ring) for province in provinces for ring in province["rings"])
    print(f"{destination} ({destination.stat().st_size} bytes, {points} puntos, {len(provinces)} provincias)")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python3 scripts/build_boundaries.py ruta/al.geojson", file=sys.stderr)
        sys.exit(2)
    build(Path(sys.argv[1]), Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_OUT)
