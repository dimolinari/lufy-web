#!/usr/bin/env python3
"""Genera el MP3 de cada lección con ElevenLabs.

La clave se lee solo de la variable de entorno ELEVENLABS_API_KEY.
Sin --yes el script imprime el costo estimado y no llama a la API.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BRAND_PATH = ROOT / "Sources" / "AprendeCore" / "Resources" / "brand.json"
CONTENT_DIR = ROOT / "Sources" / "AprendeCore" / "Resources" / "Content"
AUDIO_DIR = ROOT / "Sources" / "AprendeCore" / "Resources" / "Audio"
CACHE_DIR = ROOT / ".audio-cache"
CHUNK_LIMIT = 4500
API_URL = "https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"


@dataclass(frozen=True)
class LessonScript:
    lesson_id: str
    title: str
    text: str

    @property
    def characters(self) -> int:
        return len(self.text)


@dataclass(frozen=True)
class PlanItem:
    lesson: LessonScript
    digest: str
    characters: int
    generate: bool
    reason: str


def content_hash(model_id: str, voice_id: str, text: str) -> str:
    payload = json.dumps(
        {"model_id": model_id, "text": text, "voice_id": voice_id},
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def voice_is_configured(voice_id: str) -> bool:
    cleaned = voice_id.strip()
    if not cleaned:
        return False
    lowered = cleaned.lower()
    blocked = {"replace", "reemplazar", "todo", "changeme", "voice", "voice_id", "placeholder"}
    return lowered not in blocked and not lowered.startswith("reemplazar") and not lowered.startswith("replace")


def load_brand(path: Path = BRAND_PATH) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def load_lessons(content_dir: Path = CONTENT_DIR) -> list[LessonScript]:
    manifest = json.loads((content_dir / "manifest.json").read_text(encoding="utf-8"))
    lessons: list[LessonScript] = []
    for filename in manifest["courses"]:
        course = json.loads((content_dir / filename).read_text(encoding="utf-8"))
        for unit in course["units"]:
            for lesson in unit["lessons"]:
                lessons.append(
                    LessonScript(
                        lesson_id=lesson["id"],
                        title=lesson["title"],
                        text=lesson["script"].strip(),
                    )
                )
    return lessons


def load_cache_index(cache_dir: Path) -> dict:
    index_path = cache_dir / "index.json"
    if not index_path.exists():
        return {"lessons": {}}
    return json.loads(index_path.read_text(encoding="utf-8"))


def save_cache_index(cache_dir: Path, index: dict) -> None:
    cache_dir.mkdir(parents=True, exist_ok=True)
    (cache_dir / "index.json").write_text(
        json.dumps(index, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def plan_items(
    lessons: list[LessonScript],
    model_id: str,
    voice_id: str,
    cache_dir: Path,
    audio_dir: Path,
) -> list[PlanItem]:
    index = load_cache_index(cache_dir)
    items: list[PlanItem] = []
    for lesson in lessons:
        digest = content_hash(model_id, voice_id, lesson.text)
        cached = cache_dir / f"{digest}.mp3"
        output = audio_dir / f"{lesson.lesson_id}.mp3"
        known = index.get("lessons", {}).get(lesson.lesson_id, {})
        if known.get("hash") == digest and cached.exists() and output.exists():
            reason = "en caché, 0 créditos"
            generate = False
        elif known.get("hash") == digest and cached.exists():
            reason = "en caché, se copia al paquete, 0 créditos"
            generate = False
        else:
            reason = "se generaría"
            generate = True
        items.append(
            PlanItem(
                lesson=lesson,
                digest=digest,
                characters=lesson.characters,
                generate=generate,
                reason=reason,
            )
        )
    return items


def credits_for(items: list[PlanItem]) -> int:
    return sum(item.characters for item in items if item.generate)


def split_text(text: str, limit: int = CHUNK_LIMIT) -> list[str]:
    """Parte el guion sin perder caracteres, para que el estimado coincida con lo enviado."""
    if limit < 1:
        raise ValueError("el límite de caracteres tiene que ser positivo")
    if len(text) <= limit:
        return [text]
    chunks: list[str] = []
    start = 0
    while start < len(text):
        end = min(len(text), start + limit)
        if end < len(text):
            window = text[start:end]
            paragraph = window.rfind("\n\n")
            sentence = max(window.rfind(". "), window.rfind(".\n"))
            cut = paragraph if paragraph >= limit // 2 else sentence
            if cut >= limit // 2:
                end = start + cut + 2
        piece = text[start:end]
        if not piece:
            break
        chunks.append(piece)
        start = end
    return chunks


def synthesize(api_key: str, voice_id: str, model_id: str, text: str) -> bytes:
    parts = [synthesize_chunk(api_key, voice_id, model_id, chunk) for chunk in split_text(text)]
    return b"".join(parts)


def synthesize_chunk(api_key: str, voice_id: str, model_id: str, text: str) -> bytes:
    quoted = urllib.parse.quote(voice_id, safe="")
    url = API_URL.format(voice_id=quoted) + "?output_format=mp3_44100_128"
    payload = json.dumps({"text": text, "model_id": model_id}).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=payload,
        method="POST",
        headers={
            "xi-api-key": api_key,
            "Content-Type": "application/json",
            "Accept": "audio/mpeg",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            data = response.read()
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"ElevenLabs respondió {error.code}: {redact(body)}") from None
    if not data:
        raise RuntimeError("ElevenLabs devolvió un audio vacío.")
    return data


def redact(text: str) -> str:
    key = os.environ.get("ELEVENLABS_API_KEY", "")
    if key:
        text = text.replace(key, "[redactado]")
    return text


def print_plan(items: list[PlanItem], model_id: str, voice_id: str) -> None:
    voice = voice_id if voice_is_configured(voice_id) else "(sin configurar en brand.json)"
    print(f"Modelo: {model_id}")
    print(f"Voz: {voice}")
    print()
    print(f"{'Lección':<36} {'Caracteres':>12}  Estado")
    for item in items:
        print(f"{item.lesson.lesson_id:<36} {item.characters:>12}  {item.reason}")
    total = credits_for(items)
    print()
    print(f"Créditos estimados: {total} (1 crédito por carácter Unicode del guion que se enviaría).")
    print("Los guiones que ya están en caché con el mismo texto, modelo y voz no se vuelven a cobrar.")


def restore_cached(items: list[PlanItem], cache_dir: Path, audio_dir: Path) -> None:
    audio_dir.mkdir(parents=True, exist_ok=True)
    for item in items:
        if item.generate or "copia" not in item.reason:
            continue
        source = cache_dir / f"{item.digest}.mp3"
        target = audio_dir / f"{item.lesson.lesson_id}.mp3"
        shutil.copyfile(source, target)


def generate_missing(
    items: list[PlanItem],
    api_key: str,
    voice_id: str,
    model_id: str,
    cache_dir: Path,
    audio_dir: Path,
) -> None:
    audio_dir.mkdir(parents=True, exist_ok=True)
    cache_dir.mkdir(parents=True, exist_ok=True)
    index = load_cache_index(cache_dir)
    index.setdefault("lessons", {})
    for item in items:
        if not item.generate:
            continue
        print(f"Generando {item.lesson.lesson_id} ({item.characters} caracteres)...")
        audio = synthesize(api_key, voice_id, model_id, item.lesson.text)
        cached = cache_dir / f"{item.digest}.mp3"
        output = audio_dir / f"{item.lesson.lesson_id}.mp3"
        cached.write_bytes(audio)
        shutil.copyfile(cached, output)
        index["lessons"][item.lesson.lesson_id] = {
            "hash": item.digest,
            "characters": item.characters,
            "modelId": model_id,
        }
        save_cache_index(cache_dir, index)
        print(f"Listo: {output.relative_to(ROOT)}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Genera MP3 de las lecciones con ElevenLabs.")
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Gasta créditos y llama a la API. Sin esta bandera solo se imprime el estimado.",
    )
    parser.add_argument("--lesson", action="append", default=[], help="Limita la generación a estos id.")
    args = parser.parse_args(argv)

    brand = load_brand()
    eleven = brand["elevenlabs"]
    model_id = eleven["modelId"]
    voice_id = eleven.get("voiceId", "")
    lessons = load_lessons()
    if args.lesson:
        wanted = set(args.lesson)
        lessons = [lesson for lesson in lessons if lesson.lesson_id in wanted]
        missing = wanted - {lesson.lesson_id for lesson in lessons}
        if missing:
            print("No existe la lección: " + ", ".join(sorted(missing)), file=sys.stderr)
            return 2
    items = plan_items(lessons, model_id, voice_id, CACHE_DIR, AUDIO_DIR)
    print_plan(items, model_id, voice_id)
    pending = credits_for(items)
    if not args.yes:
        print()
        print("No se llamó a la API. Para gastar esos créditos, ejecuta de nuevo con --yes.")
        return 0
    restore_cached(items, CACHE_DIR, AUDIO_DIR)
    if pending == 0:
        print()
        print("No había lecciones nuevas. No se gastaron créditos.")
        return 0
    if not voice_is_configured(voice_id):
        print()
        print("Falta el voice id en brand.json (elevenlabs.voiceId). No se llamó a la API.", file=sys.stderr)
        return 2
    api_key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not api_key:
        print()
        print("Falta la variable de entorno ELEVENLABS_API_KEY. No se llamó a la API.", file=sys.stderr)
        return 2
    print()
    print("El estimado de arriba es lo que se va a gastar ahora.")
    generate_missing(items, api_key, voice_id, model_id, CACHE_DIR, AUDIO_DIR)
    return 0


if __name__ == "__main__":
    sys.exit(main())
