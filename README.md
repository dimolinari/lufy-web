# Lufy · web pública

Web estática de Lufy: el libro «El verdadero poder político. Ecuador 1972–2023» y hilos con datos oficiales del Ecuador.

- Sitio: https://dimolinari.github.io/lufy-web/
- HTML y CSS estáticos, sin cookies, sin analítica y sin rastreadores. La meta «Cerebro para Lufy» se lee con un script local (`assets/js/meta.js`) desde `data/meta.json`.
- Publicación: GitHub Pages desde la rama `main` (carpeta raíz).
- La tarjeta para compartir está en `assets/img/og.svg` (dibujo original) y `assets/img/og.png` (el mismo dibujo, exportado).

## La web pública de Lufy

- El diseño es original de Lufy. No se copian maquetas, textos, gráficos ni cifras de informes de otras organizaciones.
- La página de Lufy es el destino. Los datos no se enlazan hacia sitios oficiales: cada cifra lleva una línea de fuente (institución, documento y fecha).
- Esa línea de fuente abre una copia archivada alojada por Lufy, con su huella SHA-256, cuando la copia ya está en el repositorio. Si todavía no está, la línea se muestra como texto y en el HTML queda un comentario `TODO` para enlazarla. No se inventa la huella.
- Las publicaciones en X enlazan a la página de Lufy (el inicio, un hilo o el libro), no al documento en un sitio oficial.
- El sitio se publica solo con el nombre Lufy: sin nombre personal, cédula, teléfono ni correos personales.
- El contenido principal es gratis. Solo se publican datos oficiales verificados. No hay acusaciones: cada hallazgo va con CONFIRMADO, INDICIO, ABIERTO o HIPÓTESIS.
- En Datos hay dos fichas: Mishel Andrea Mancheno Dávila y Luis Esteban Torres Cobo. Cada dato va como ABIERTO: la copia archivada con SHA-256 no está en el repositorio y no se inventa la huella. Los retratos están en `assets/img/mishel-andrea-mancheno-davila.png` y `assets/img/luis-esteban-torres-cobo.jpg`.

Reglas de contenido, con más detalle: `historia.html`.

## Meta «Cerebro para Lufy»

La cifra recaudada vive solo en `data/meta.json`. Para actualizarla, cambia `raised_usd` y la fecha `updated` (`AAAA-MM-DD`). `goal_usd` es la meta. No inventes montos, donantes ni conteos.

© 2026 Lufy.
