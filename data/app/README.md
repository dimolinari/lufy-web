# Feed de la app (`/data/app/v1/`)

Índice versionado para actualizar la app sin una versión nueva en la tienda. El manifiesto es genérico: otra app puede publicar el mismo formato con otro `id` y otros archivos. Lufy publica `id` `lufy`.

La copia de este repositorio es **dato de ejemplo**. No describe a integrantes reales de la Asamblea Nacional.

## Generar

El proceso diario deja CSV o JSON en `data/app/entrada/` y corre, sin red:

```bash
python3 data/app/generar_feed.py
```

`--entrada` y `--salida` cambian las carpetas. Por defecto lee `data/app/entrada` y escribe `data/app/v1`.

El script rechaza el archivo si aparece un número de 10 dígitos, un correo, un enlace a un sitio oficial, un campo fuera del esquema (cédula, domicilio, teléfono, familiares, patrimonio, monto) o un sello que no sea CONFIRMADO, INDICIO, ABIERTO o HIPÓTESIS. Con `"ejemplo": true`, cada nombre tiene que incluir la palabra Ejemplo y el aviso también.

## Entrada

`meta.json`

```json
{
  "ejemplo": true,
  "aviso": "DATOS DE EJEMPLO. Nombres ficticios. No son asambleístas reales.",
  "updated_at": "2026-09-27T00:00:00Z",
  "periodo": { "id": "ejemplo-2026", "etiqueta": "Período de ejemplo", "inicio": "2026-01-01", "fin": null }
}
```

`updated_at` es `AAAA-MM-DD` o `AAAA-MM-DDTHH:MM:SSZ`.

Si existe `asambleistas.json` con una lista `asambleistas` ya anidada, se usa esa lista. Si no, se arman los perfiles con:

- `asambleistas.csv`: `id`, `nombre`, `provincia`, `circunscripcion`, `partido`, `bloque`, `comisiones` (separadas por `|`), `periodo`, `foto`, `licencia`, `atribucion`. Foto vacía significa iniciales. Licencias admitidas: `dominio-publico`, `cc0`, `cc-by`.
- `proyectos.csv` (opcional): `asambleista_id`, `id`, `titulo`, `fecha`, `estado`, `institucion`, `documento`, `fecha_fuente`, `linea`.
- `asistencia.csv` (opcional): `asambleista_id`, `sesiones`, `presente`, y la misma fuente.
- `votaciones.csv` y `votos.csv`: la votación (`id`, `fecha`, `titulo`, `sesion`, `acta` y la fuente) y cada fila `votacion_id`, `asambleista_id`, `voto`. El voto es `afavor`, `en_contra`, `abstencion`, `ausente` o `blanco`. No lleva sello.
- `hallazgos.json`: lista `hallazgos` con `id`, `sello`, `titulo`, `texto`, `asambleistas`, `fuente`. Opcionales: `tema` (texto corto, o vacío) y `early_access_until` (null, `AAAA-MM-DD` o `AAAA-MM-DDTHH:MM:SSZ`). Si omites la fecha y `meta.json` trae `dias_acceso_anticipado` (entero de 0 a 366), el generador suma esos días a `updated_at`. La convención es 7. Si la clave ya está, aunque sea null, no se recalcula.
- `dossiers.json` (opcional): lista `dossiers` con `id`, `titulo`, `texto`, `producto` (`com.lufy.app.dossier.ejemplo` en el corte de ejemplo), `fuente`, y opcionales `tema`, `early_access_until`, `archivo`. Sin este archivo, el feed publica la lista vacía. `archivo` queda null hasta que Lufy aloje el dossier. El producto es un identificador de tienda, no un enlace.

`id` de perfil, proyecto, votación y hallazgo: minúsculas, dígitos y guiones, hasta 64 caracteres.

La línea de fuente es texto (institución, documento, fecha). `archivo` queda en null hasta que Lufy aloje la copia. Si se llena, es `{ "ruta", "sha256", "archivado" }` con ruta relativa dentro del sitio de Lufy, huella de 64 hex y fecha `AAAA-MM-DD`.

## Salida

`manifest.json`

```json
{
  "schema": 1,
  "id": "lufy",
  "updated_at": "2026-09-27T00:00:00Z",
  "files": [
    { "path": "asamblea.json", "sha256": "<64 hex>", "updated_at": "2026-09-27T00:00:00Z", "bytes": 2898 }
  ]
}
```

`path` es relativo, sin `..` ni barra inicial. `bytes` es el tamaño exacto del archivo. La app solo sustituye un archivo si el sha256 y el tamaño coinciden. Un archivo extra en `files` se guarda y se ignora hasta que la app sepa leerlo. Subir `schema` de 1 exige una versión nueva de la app.

`asamblea.json`: `schema`, `ejemplo`, `aviso`, `updated_at`, `periodo` (`id`, `etiqueta`, `inicio`, `fin`) y `asambleistas`. Cada perfil: `id`, `nombre`, `foto` (objeto o null), `provincia`, `circunscripcion`, `partido`, `bloque`, `comisiones`, `periodo`, `proyectos`, `asistencia` (objeto o null), `hallazgos` (ids). El generador rellena `hallazgos` a partir de `hallazgos.json`.

`hallazgos.json`: `schema`, `ejemplo`, `updated_at`, `hallazgos`. Cada hallazgo incluye `tema` y `early_access_until` (null o fecha).

`dossiers.json`: `schema`, `ejemplo`, `updated_at`, `dossiers`. Cada ficha: `id`, `titulo`, `texto`, `tema`, `producto`, `early_access_until`, `archivo` (objeto o null), `fuente`. Con la capa de pago apagada la app no ofrece esta lista. Con la capa encendida, un `early_access_until` futuro se esconde hasta la fecha, salvo suscripción o compra de ese producto.

`votaciones/<id>.json`: `schema`, `id`, `fecha`, `titulo`, `sesion`, `acta`, `fuente`, `votos` (`asambleista_id`, `voto`). Un archivo por votación, para no rebajar el resto cuando cambia una sola. Un voto no lleva sello.
