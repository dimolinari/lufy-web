#!/bin/sh
# Copia el índice público y el adjunto al paquete de la app.
# El sitio y la app leen los mismos bytes.
set -eu
raiz=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
cp "$raiz/data/contenido.json" "$raiz/apple/Sources/LufyCore/Resources/contenido.json"
cp "$raiz/data/meta.json" "$raiz/apple/Sources/LufyCore/Resources/meta.json"
cp "$raiz/datos/cne-elecciones-generales-2025.csv" "$raiz/apple/Sources/LufyCore/Resources/cne-elecciones-generales-2025.csv"
