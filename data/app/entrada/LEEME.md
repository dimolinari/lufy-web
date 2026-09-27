# Entrada de ejemplo

Estos archivos son **DATOS DE EJEMPLO**. Los nombres («Asambleísta Ejemplo 1», «Asambleísta Ejemplo 2») son ficticios. No son integrantes de la Asamblea Nacional.

Sustituye esta carpeta por el exporte diario del archivo y vuelve a correr `python3 data/app/generar_feed.py`. Cuando los datos sean los publicados, `meta.json` lleva `"ejemplo": false`.

`hallazgos.json` puede traer `tema` y `early_access_until` (null o una fecha). `dossiers.json` es opcional: si no está, el feed publica la lista vacía. El dossier de ejemplo no trae archivo.
