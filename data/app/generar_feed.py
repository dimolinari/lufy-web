#!/usr/bin/env python3
"""Arma el feed versionado de la app a partir de exportes locales.

No usa la red. Lee CSV y JSON de una carpeta de entrada, rechaza cédulas,
correos y campos que no están en el esquema, y escribe manifest.json con
sha256.

Uso:
    python3 data/app/generar_feed.py
    python3 data/app/generar_feed.py --entrada data/app/entrada --salida data/app/v1
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
from pathlib import Path

CEDULA = re.compile(r"\b\d{10}\b")
CORREO = re.compile(r"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", re.IGNORECASE)
FECHA = re.compile(r"^\d{4}-\d{2}-\d{2}$")
MARCA = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
ID = re.compile(r"^[a-z0-9-]{1,64}$")
SELLOS = {"CONFIRMADO", "INDICIO", "ABIERTO", "HIPÓTESIS"}
VOTOS = {"afavor", "en_contra", "abstencion", "ausente", "blanco"}
LICENCIAS = {"dominio-publico", "cc0", "cc-by"}
PALABRAS = (
    "testa" + "ferro",
    "cul" + "pable",
    "guil" + "ty",
    "corrup" + "to",
    "corrup" + "ta",
)
CLAVES = {
    "cedula",
    "email",
    "correo",
    "mail",
    "domicilio",
    "direccion",
    "telefono",
    "patrimonio",
    "declaracion",
    "familia",
    "conyuge",
    "hijos",
    "monto",
}


def fallar(mensaje: str) -> None:
    print(mensaje, file=sys.stderr)
    raise SystemExit(1)


def marca_valida(texto: str) -> bool:
    return bool(FECHA.match(texto) or MARCA.match(texto))


def revisar_texto(texto: str, donde: str) -> None:
    if not isinstance(texto, str):
        fallar(f"{donde}: se esperaba texto")
    plano = texto.casefold()
    for palabra in PALABRAS:
        if palabra in plano:
            fallar(f"{donde}: redacción no permitida")
    if CEDULA.search(texto):
        fallar(f"{donde}: número de 10 dígitos")
    if CORREO.search(texto):
        fallar(f"{donde}: correo")
    if "gob.ec" in texto.lower() or "archive.org" in texto.lower():
        fallar(f"{donde}: enlace no permitido")


def revisar_clave(clave: str, donde: str) -> None:
    if clave.casefold() in CLAVES:
        fallar(f"{donde}: campo no permitido")


def leer_json(ruta: Path):
    try:
        return json.loads(ruta.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fallar(f"{ruta.name}: JSON inválido ({error})")


def leer_csv(ruta: Path) -> list[dict[str, str]]:
    with ruta.open(encoding="utf-8-sig", newline="") as archivo:
        lector = csv.DictReader(archivo)
        if lector.fieldnames is None:
            fallar(f"{ruta.name}: sin cabecera")
        for campo in lector.fieldnames:
            revisar_clave(campo, ruta.name)
        filas = []
        for fila in lector:
            limpia = {}
            for clave, valor in fila.items():
                if clave is None:
                    fallar(f"{ruta.name}: columna de más")
                revisar_clave(clave, ruta.name)
                limpia[clave] = (valor or "").strip()
                revisar_texto(limpia[clave], f"{ruta.name}:{clave}")
            filas.append(limpia)
        return filas


def revisar_arbol(valor, donde: str = "feed") -> None:
    if isinstance(valor, str):
        revisar_texto(valor, donde)
    elif isinstance(valor, dict):
        for clave, contenido in valor.items():
            revisar_clave(clave, donde)
            revisar_arbol(contenido, clave)
    elif isinstance(valor, list):
        for contenido in valor:
            revisar_arbol(contenido, donde)
    elif isinstance(valor, bool) or valor is None:
        return
    elif isinstance(valor, int):
        if re.fullmatch(r"\d{10}", str(valor)):
            fallar(f"{donde}: número de 10 dígitos")
    else:
        fallar(f"{donde}: tipo no permitido")


def archivo_de(valor, donde: str):
    if valor is None:
        return None
    if not isinstance(valor, dict):
        fallar(f"{donde}: archivo inválido")
    for campo in ("ruta", "sha256", "archivado"):
        if campo not in valor:
            fallar(f"{donde}: archivo incompleto")
    if not re.fullmatch(r"[0-9a-f]{64}", str(valor["sha256"])):
        fallar(f"{donde}: huella inválida")
    if not FECHA.match(str(valor["archivado"])):
        fallar(f"{donde}: fecha de archivo inválida")
    ruta = str(valor["ruta"])
    if ruta.startswith("/") or ".." in ruta or "://" in ruta or not ruta:
        fallar(f"{donde}: ruta de archivo no permitida")
    revisar_texto(ruta, donde)
    return {"ruta": ruta, "sha256": valor["sha256"], "archivado": valor["archivado"]}


def fuente_de(fila: dict[str, str]) -> dict:
    for campo in ("institucion", "documento", "fecha_fuente", "linea"):
        if campo not in fila or not fila[campo]:
            fallar(f"falta {campo} en una fuente")
    if not FECHA.match(fila["fecha_fuente"]):
        fallar("fecha de fuente inválida")
    revisar_texto(fila["linea"], "linea")
    return {
        "institucion": fila["institucion"],
        "documento": fila["documento"],
        "fecha": fila["fecha_fuente"],
        "linea": fila["linea"],
        "archivo": None,
    }


def partir(texto: str) -> list[str]:
    if not texto:
        return []
    partes = [parte.strip() for parte in texto.split("|")]
    if any(not parte for parte in partes):
        fallar("lista con un elemento vacío")
    return partes


def foto_de(fila: dict[str, str]) -> dict | None:
    ruta = fila.get("foto", "")
    licencia = fila.get("licencia", "")
    atribucion = fila.get("atribucion", "")
    if not ruta and not licencia and not atribucion:
        return None
    if not ruta or licencia not in LICENCIAS or not atribucion:
        fallar(f"{fila.get('id', '?')}: la foto solo se publica con licencia abierta")
    if ruta.startswith("/") or ".." in ruta or "://" in ruta:
        fallar("ruta de foto no permitida")
    return {"ruta": ruta, "licencia": licencia, "atribucion": atribucion}


def construir(entrada: Path) -> tuple[dict, dict, list[dict]]:
    meta_ruta = entrada / "meta.json"
    if not meta_ruta.is_file():
        fallar("falta meta.json")
    meta = leer_json(meta_ruta)
    if not isinstance(meta, dict):
        fallar("meta.json: se esperaba un objeto")
    for clave in meta:
        revisar_clave(clave, "meta")
    for clave in ("ejemplo", "aviso", "updated_at", "periodo"):
        if clave not in meta:
            fallar(f"meta.json: falta {clave}")
    if not isinstance(meta["ejemplo"], bool):
        fallar("ejemplo debe ser true o false")
    if not isinstance(meta["aviso"], str):
        fallar("aviso debe ser texto")
    revisar_texto(meta["aviso"], "aviso")
    if not marca_valida(meta["updated_at"]):
        fallar("updated_at inválido")
    periodo = meta["periodo"]
    if not isinstance(periodo, dict):
        fallar("periodo inválido")
    for clave in periodo:
        revisar_clave(clave, "periodo")
    for clave in ("id", "etiqueta", "inicio", "fin"):
        if clave not in periodo:
            fallar(f"periodo: falta {clave}")
    if not ID.match(str(periodo["id"])):
        fallar("id de periodo inválido")
    revisar_texto(str(periodo["etiqueta"]), "periodo")
    if not FECHA.match(str(periodo["inicio"])):
        fallar("inicio de periodo inválido")
    if periodo["fin"] is not None and not FECHA.match(str(periodo["fin"])):
        fallar("fin de periodo inválido")
    if meta["ejemplo"] and "ejemplo" not in meta["aviso"].casefold():
        fallar("un feed de ejemplo tiene que decirlo en el aviso")

    if (entrada / "asambleistas.json").is_file():
        crudo = leer_json(entrada / "asambleistas.json")
        if not isinstance(crudo, dict) or not isinstance(crudo.get("asambleistas"), list):
            fallar("asambleistas.json: falta la lista asambleistas")
        personas = crudo["asambleistas"]
    else:
        personas = desde_csv(entrada)

    hallazgos = hallazgos_de(entrada)
    votaciones = votaciones_de(entrada, {p["id"] for p in personas})
    citados: dict[str, list[str]] = {p["id"]: [] for p in personas}
    for hallazgo in hallazgos["hallazgos"]:
        for pid in hallazgo["asambleistas"]:
            if pid not in citados:
                fallar(f"hallazgo {hallazgo['id']} cita un perfil que no existe")
            citados[pid].append(hallazgo["id"])
    for persona in personas:
        persona["hallazgos"] = citados[persona["id"]]
        if meta["ejemplo"] and "ejemplo" not in persona["nombre"].casefold():
            fallar(f"{persona['id']}: en un feed de ejemplo el nombre tiene que incluir Ejemplo")

    if not personas:
        fallar("el feed no tiene perfiles")

    asamblea = {
        "schema": 1,
        "ejemplo": meta["ejemplo"],
        "aviso": meta["aviso"],
        "updated_at": meta["updated_at"],
        "periodo": {
            "id": periodo["id"],
            "etiqueta": periodo["etiqueta"],
            "inicio": periodo["inicio"],
            "fin": periodo["fin"],
        },
        "asambleistas": personas,
    }
    indice = {
        "schema": 1,
        "ejemplo": meta["ejemplo"],
        "updated_at": meta["updated_at"],
        "hallazgos": hallazgos["hallazgos"],
    }
    return asamblea, indice, votaciones


def desde_csv(entrada: Path) -> list[dict]:
    ruta = entrada / "asambleistas.csv"
    if not ruta.is_file():
        fallar("falta asambleistas.csv o asambleistas.json")
    filas = leer_csv(ruta)
    personas = []
    vistos = set()
    for fila in filas:
        for campo in ("id", "nombre", "provincia", "circunscripcion", "partido", "bloque", "periodo"):
            if not fila.get(campo):
                fallar(f"asambleistas.csv: falta {campo}")
        if not ID.match(fila["id"]):
            fallar(f"id inválido: {fila['id']}")
        if fila["id"] in vistos:
            fallar(f"id repetido: {fila['id']}")
        vistos.add(fila["id"])
        personas.append(
            {
                "id": fila["id"],
                "nombre": fila["nombre"],
                "foto": foto_de(fila),
                "provincia": fila["provincia"],
                "circunscripcion": fila["circunscripcion"],
                "partido": fila["partido"],
                "bloque": fila["bloque"],
                "comisiones": partir(fila.get("comisiones", "")),
                "periodo": fila["periodo"],
                "proyectos": [],
                "asistencia": None,
                "hallazgos": [],
            }
        )
    por_id = {p["id"]: p for p in personas}
    if (entrada / "proyectos.csv").is_file():
        for fila in leer_csv(entrada / "proyectos.csv"):
            pid = fila.get("asambleista_id", "")
            if pid not in por_id:
                fallar(f"proyecto sin perfil: {pid}")
            if not ID.match(fila.get("id", "")) or not FECHA.match(fila.get("fecha", "")):
                fallar("proyecto inválido")
            if not fila.get("titulo") or not fila.get("estado"):
                fallar("proyecto incompleto")
            por_id[pid]["proyectos"].append(
                {
                    "id": fila["id"],
                    "titulo": fila["titulo"],
                    "fecha": fila["fecha"],
                    "estado": fila["estado"],
                    "fuente": fuente_de(fila),
                }
            )
    if (entrada / "asistencia.csv").is_file():
        for fila in leer_csv(entrada / "asistencia.csv"):
            pid = fila.get("asambleista_id", "")
            if pid not in por_id:
                fallar(f"asistencia sin perfil: {pid}")
            try:
                sesiones = int(fila["sesiones"])
                presente = int(fila["presente"])
            except (KeyError, ValueError):
                fallar("asistencia inválida")
            if sesiones < 0 or presente < 0 or presente > sesiones:
                fallar("asistencia fuera de rango")
            if por_id[pid]["asistencia"] is not None:
                fallar(f"asistencia repetida: {pid}")
            por_id[pid]["asistencia"] = {
                "sesiones": sesiones,
                "presente": presente,
                "fuente": fuente_de(fila),
            }
    return personas


def hallazgos_de(entrada: Path) -> dict:
    ruta = entrada / "hallazgos.json"
    if not ruta.is_file():
        fallar("falta hallazgos.json")
    datos = leer_json(ruta)
    lista = datos.get("hallazgos") if isinstance(datos, dict) else None
    if not isinstance(lista, list):
        fallar("hallazgos.json: falta la lista")
    vistos = set()
    limpios = []
    for item in lista:
        if not isinstance(item, dict):
            fallar("hallazgo inválido")
        for clave in item:
            revisar_clave(clave, "hallazgo")
        for campo in ("id", "sello", "titulo", "texto", "asambleistas", "fuente"):
            if campo not in item:
                fallar("hallazgo incompleto")
        if not ID.match(str(item["id"])):
            fallar("id de hallazgo inválido")
        if item["id"] in vistos:
            fallar("hallazgo repetido")
        vistos.add(item["id"])
        if item["sello"] not in SELLOS:
            fallar("sello no reconocido")
        revisar_texto(item["titulo"], "hallazgo")
        revisar_texto(item["texto"], "hallazgo")
        if not isinstance(item["asambleistas"], list) or not item["asambleistas"]:
            fallar("el hallazgo tiene que citar al menos un perfil")
        for pid in item["asambleistas"]:
            revisar_texto(str(pid), "hallazgo")
            if not ID.match(str(pid)):
                fallar("id citado inválido")
        fuente = item["fuente"]
        if not isinstance(fuente, dict):
            fallar("fuente de hallazgo inválida")
        for campo in ("institucion", "documento", "fecha", "linea", "archivo"):
            if campo not in fuente:
                fallar("fuente de hallazgo incompleta")
        revisar_texto(str(fuente["linea"]), "hallazgo")
        if not FECHA.match(str(fuente["fecha"])):
            fallar("fecha de fuente inválida")
        for campo in ("institucion", "documento", "linea"):
            revisar_texto(str(fuente[campo]), "hallazgo")
        limpios.append(
            {
                "id": item["id"],
                "sello": item["sello"],
                "titulo": item["titulo"],
                "texto": item["texto"],
                "asambleistas": list(item["asambleistas"]),
                "fuente": {
                    "institucion": fuente["institucion"],
                    "documento": fuente["documento"],
                    "fecha": fuente["fecha"],
                    "linea": fuente["linea"],
                    "archivo": archivo_de(fuente["archivo"], "hallazgo"),
                },
            }
        )
    return {"hallazgos": limpios}


def votaciones_de(entrada: Path, ids: set[str]) -> list[dict]:
    meta = entrada / "votaciones.csv"
    votos_ruta = entrada / "votos.csv"
    if not meta.is_file():
        return []
    sesiones = []
    votos: dict[str, list[dict]] = {}
    if votos_ruta.is_file():
        for fila in leer_csv(votos_ruta):
            vid = fila.get("votacion_id", "")
            pid = fila.get("asambleista_id", "")
            sentido = fila.get("voto", "")
            if not ID.match(vid) or pid not in ids or sentido not in VOTOS:
                fallar("voto inválido")
            votos.setdefault(vid, []).append({"asambleista_id": pid, "voto": sentido})
    vistos = set()
    for fila in leer_csv(meta):
        vid = fila.get("id", "")
        if not ID.match(vid) or vid in vistos:
            fallar("votación inválida o repetida")
        vistos.add(vid)
        if not FECHA.match(fila.get("fecha", "")):
            fallar("fecha de votación inválida")
        for campo in ("titulo", "sesion", "acta"):
            if not fila.get(campo):
                fallar(f"votación sin {campo}")
        registros = votos.get(vid, [])
        if len({r["asambleista_id"] for r in registros}) != len(registros):
            fallar(f"voto repetido en {vid}")
        sesiones.append(
            {
                "schema": 1,
                "id": vid,
                "fecha": fila["fecha"],
                "titulo": fila["titulo"],
                "sesion": fila["sesion"],
                "acta": fila["acta"],
                "fuente": fuente_de(fila),
                "votos": registros,
            }
        )
    return sesiones


def volcar(obj) -> bytes:
    return (json.dumps(obj, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def escribir(salida: Path, asamblea: dict, hallazgos: dict, votaciones: list[dict], marca: str) -> None:
    if salida.exists():
        for ruta in salida.rglob("*"):
            if ruta.is_file():
                ruta.unlink()
    else:
        salida.mkdir(parents=True)
    archivos: list[tuple[str, bytes]] = [
        ("asamblea.json", volcar(asamblea)),
        ("hallazgos.json", volcar(hallazgos)),
    ]
    for votacion in votaciones:
        archivos.append((f"votaciones/{votacion['id']}.json", volcar(votacion)))
    entradas = []
    for relativo, datos in sorted(archivos, key=lambda item: item[0]):
        destino = salida / relativo
        destino.parent.mkdir(parents=True, exist_ok=True)
        destino.write_bytes(datos)
        entradas.append(
            {
                "path": relativo,
                "sha256": hashlib.sha256(datos).hexdigest(),
                "updated_at": marca,
                "bytes": len(datos),
            }
        )
    manifiesto = {
        "schema": 1,
        "id": "lufy",
        "updated_at": marca,
        "files": entradas,
    }
    (salida / "manifest.json").write_bytes(volcar(manifiesto))


def main() -> None:
    raiz = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description="Genera data/app/v1 desde exportes locales.")
    parser.add_argument("--entrada", type=Path, default=raiz / "data" / "app" / "entrada")
    parser.add_argument("--salida", type=Path, default=raiz / "data" / "app" / "v1")
    args = parser.parse_args()
    asamblea, hallazgos, votaciones = construir(args.entrada)
    revisar_arbol(asamblea)
    revisar_arbol(hallazgos)
    revisar_arbol(votaciones)
    escribir(args.salida, asamblea, hallazgos, votaciones, asamblea["updated_at"])
    print(f"Feed escrito en {args.salida} ({len(votaciones)} votaciones)")


if __name__ == "__main__":
    main()
