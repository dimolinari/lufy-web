#!/usr/bin/env python3
"""Icono provisional: rectángulo vino y balanza en oro, el mismo dibujo que favicon.svg."""

from pathlib import Path

from PIL import Image, ImageDraw

VINO = (0x3D, 0x18, 0x20)
ORO = (0xD4, 0xB3, 0x6A)
DESTINO = Path(__file__).resolve().parents[1] / "App" / "Assets.xcassets" / "AppIcon.appiconset"


def icono(lado: int) -> Image.Image:
    imagen = Image.new("RGB", (lado, lado), VINO)
    dibujo = ImageDraw.Draw(imagen)
    escala = lado / 64
    grosor = max(1, round(3 * escala))

    def p(x: float, y: float) -> tuple[float, float]:
        return (x * escala, y * escala)

    dibujo.line([p(32, 12), p(32, 38)], fill=ORO, width=grosor)
    dibujo.line([p(20, 46), p(44, 46)], fill=ORO, width=grosor)
    dibujo.line([p(16, 20), p(48, 20)], fill=ORO, width=grosor)
    dibujo.line([p(16, 20), p(10, 34), p(22, 34), p(16, 20)], fill=ORO, width=grosor, joint="curve")
    dibujo.line([p(48, 20), p(42, 34), p(54, 34), p(48, 20)], fill=ORO, width=grosor, joint="curve")
    return imagen


def main() -> None:
    DESTINO.mkdir(parents=True, exist_ok=True)
    lados = [16, 32, 64, 128, 256, 512, 1024]
    for lado in lados:
        icono(lado).save(DESTINO / f"icono-{lado}.png", format="PNG")


if __name__ == "__main__":
    main()
