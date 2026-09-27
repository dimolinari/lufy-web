# Lufy Aprende

App nativa para aprender, en voz alta, cómo funciona lo público en el Ecuador. Cada lección es un audiolibro corto, de tres a seis minutos. Después hay unas preguntas. Si fallas alguna, vuelve al día siguiente.

El nombre visible de la app está en un solo archivo: `Sources/AprendeCore/Resources/brand.json`. Hoy dice **Lufy Aprende**. La lógica de cursos, puntajes, racha y repaso vive en el paquete Swift `AprendeCore`, sin red y sin cuenta.

Esta carpeta no toca la web de Lufy.

## Qué hay aquí

- `Sources/AprendeCore`: contenido, puntuación, XP, racha, repaso espaciado y la regla de cursos gratis o de pago.
- `Tests/AprendeCoreTests`: pruebas que corren con `swift test`, también en Linux.
- `App`: interfaz SwiftUI para iOS 17, macOS 14 y visionOS 2. El mismo paquete `AprendeCore` arma el mapa, las barras y el hemiciclo.
- `project.yml`: definición del proyecto para XcodeGen.
- `scripts/generate_audio.py`: voz grabada opcional, con ElevenLabs. La app no lo necesita para funcionar.
- `Sources/AprendeCore/Resources/Data`: series y el esquema de provincias, cada uno con su fuente.
- `Sources/AprendeCore/Resources/Media`: cuatro fotos pequeñas y `credits.json`.
- `Sources/AprendeCore/Resources/Spatial`: contornos de las 24 provincias, simplificados desde geoBoundaries (CC0). No hay elevación.
- `scripts/setup.sh`: escribe el nombre en el proyecto de Xcode y lo genera.

La versión 1 es gratis. El camino **Gobierno y lo público** trae la unidad completa: cinco lecciones (cómo se hace una ley, cómo compra el Estado, cómo se lee un contrato, cómo se pide información y una primera mirada a las eras). Los demás caminos publican una lección de muestra, y Finanzas publica dos:

- Historia por eras.
- Geografía y regiones.
- Provincias.
- Naturaleza y biodiversidad.
- Cultura y pueblos.
- Economía.
- Finanzas, con un aviso de que no es asesoría ni una recomendación de compra.
- Conoce tu Asamblea: una lección sobre la institución y la pantalla **Tu provincia**.

Hay gráficos para recorrer con el dedo, un esquema de provincias y una calculadora de interés compuesto. Las series numéricas salen del Banco Mundial y llevan institución, indicador y fecha. Si un archivo tuviera `exampleData: true`, la pantalla muestra **DATOS DE EJEMPLO**. Las fotos son pocas, de Wikimedia Commons, con autor y licencia en `Resources/Media/credits.json`.

## Conoce tu Asamblea

La pantalla **Tu provincia** lista asambleístas de una provincia, de la circunscripción nacional o del exterior: organización, comisiones y votos registrados, cada voto con su línea de fuente. Solo datos de la función pública. No hay fotos en la copia de ejemplo. La app no publica cédula, dirección, familia, patrimonio ni etiquetas sobre la conducta de una persona.

El contrato del archivo diario está en `data/app/v1/SCHEMA.md`, en la raíz del repositorio, que es la ruta `/data/app/v1/` del sitio. Hoy `manifest.json` y `asamblea.json` son **datos de ejemplo**, con nombres ficticios. La app los trae para funcionar sin red. Comprueba la huella SHA-256 antes de reemplazar la copia guardada, consulta como mucho una vez por día civil del Ecuador, y si la descarga falla se queda con la copia anterior. La fecha sale en pantalla como «Actualizado: …».

Para apuntar a un manifiesto publicado, pega su URL en `brand.json`, dentro de `asambleaFeed.manifestURL`. Si ese campo queda vacío, no hay ninguna consulta de red.

Otras lecciones de cada camino aparecen como «Próximamente». No se pueden comprar. El código de StoreKit 2 ya está, pero no hay productos configurados y ningún curso publicado está bloqueado.

## Probar la lógica, sin Mac

Desde esta carpeta:

```bash
cd aprende
swift test
python3 -m unittest scripts/test_generate_audio.py
```

Hace falta Swift 6. En esta revisión las pruebas se corrieron con Swift 6.2.3 en Linux.

## Abrir el proyecto en un Mac con Xcode 26

Hacen falta Xcode 26 y [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
cd aprende
./scripts/setup.sh
open LufyAprende.xcodeproj
```

`setup.sh` lee `brand.json`, actualiza el nombre y los identificadores dentro de `project.yml`, y genera `LufyAprende.xcodeproj`. Ese proyecto no se versiona.

Para compilar el iPhone simulado desde la terminal, mira primero los destinos que tiene tu Xcode y usa uno de esa lista:

```bash
xcodebuild -scheme LufyAprende -showdestinations
xcodebuild -scheme LufyAprende -destination 'platform=iOS Simulator,name=iPhone 16' build
```

La app de Mac:

```bash
xcodebuild -scheme LufyAprendeMac -destination 'platform=macOS' build
```

Apple Vision Pro, en el simulador (no hace falta un visor):

```bash
xcodebuild -scheme LufyAprendeVision -showdestinations
xcodebuild -scheme LufyAprendeVision -destination 'platform=visionOS Simulator,name=Apple Vision Pro' build
```

En Xcode, elige el esquema **LufyAprendeVision** y el destino **Apple Vision Pro**. La ventana principal trae las lecciones. Desde un mapa, un gráfico o el hemiciclo puedes abrir un **volumen** con el modelo y, si quieres, entrar al **salón**: ahí la narración suena con la voz del dispositivo mientras caminas alrededor. El simulador deja mirar y desplazarte sin un visor físico.

El identificador de paquete de partida es `com.lufy.aprende`. El de Mac es `com.lufy.aprende.mac` y el de visionOS es `com.lufy.aprende.vision`. El team de partida es `XXXXXXXXXX`. Son marcadores. Cámbialos en `brand.json` y vuelve a correr `./scripts/setup.sh` antes de firmar.

## Ver el mapa en el iPhone

La realidad aumentada pide un iPhone o un iPad de verdad. El simulador de iOS no coloca modelos en una mesa.

1. Compila el esquema **LufyAprende** en tu iPhone, con el mismo Apple ID de la sección de abajo.
2. Abre la lección **Cuatro regiones** o **Veinticuatro provincias** y pulsa **Ver el mapa sobre la mesa**. En Economía y en Finanzas, cada gráfico tiene **Ver … en 3D**. En **Tu provincia**, el botón es **Ver el hemiciclo en 3D**.
3. La primera vez, iOS pide la cámara. Las imágenes no se guardan ni se envían. El manifiesto de privacidad sigue diciendo que no se recolectan datos.
4. Apunta a una mesa con luz y toca la pantalla para soltar el modelo. Después toca una provincia, una barra o un escaño para leer la ficha.
5. **Volver a colocar** lo mueve de nuevo. **Ver sin cámara** gira el mismo modelo, que es también lo que aparece si el aparato no tiene AR.

El grosor de las provincias es uniforme. No es la altitud de los Andes: las teselas SRTM públicas pesan unos 18 MB cada una y no van en la app. Galápagos está en un recuadro al oeste, no a la distancia real. La forma sale de geoBoundaries, gbOpen ECU ADM1, licencia CC0 (publicación `9469f09`, consultada el 27 de septiembre de 2026). La ficha de geoBoundaries nombra como fuente a geoBoundaries y Wikimedia Commons. La región (Costa, Sierra, Amazonía, Región Insular) lleva la marca **CONFIRMADO**: es la clasificación de la lección, no una altura.

Las barras usan la serie de la lección. El verde es un número cero o positivo y el rojo es negativo. El color describe el signo. No es una recomendación. Si una serie dijera datos de ejemplo, la ficha no llevaría CONFIRMADO.

El hemiciclo pinta el voto registrado en el archivo del día. La copia que viene con la app es **DATOS DE EJEMPLO**, con nombres ficticios. Un escaño gris claro no tiene registro en esa votación: no se inventa un «ausente».

Para rehacer los contornos a partir del GeoJSON simplificado de geoBoundaries:

```bash
python3 scripts/build_boundaries.py ruta/geoBoundaries-ECU-ADM1_simplified.geojson
```

El script no llama a la red. El JSON que queda pesa unos 16 KB.

## Instalarla en un iPhone con un Apple ID gratis

1. Crea un Apple ID en [appleid.apple.com](https://appleid.apple.com) si todavía no tienes uno. No hace falta pagar el programa de desarrollador.
2. En Xcode: Settings → Accounts → añade ese Apple ID.
3. Abre `LufyAprende.xcodeproj`.
4. Elige el target **LufyAprende**, pestaña Signing & Capabilities, y en Team selecciona tu equipo personal (Personal Team).
5. Si Xcode dice que `com.lufy.aprende` ya está ocupado, cambia `bundleIdentifier` en `brand.json`, corre `./scripts/setup.sh` y vuelve a abrir el proyecto.
6. Conecta el iPhone, desbloquéalo y confía en la computadora.
7. En iOS 16 o posterior, activa el modo de desarrollador: Ajustes → Privacidad y seguridad → Modo de desarrollador.
8. En Xcode elige ese iPhone como destino y pulsa Run.
9. En el iPhone: Ajustes → General → VPN y gestión de dispositivos → confía en el certificado de desarrollador.
10. Un perfil gratuito caduca a los 7 días. Para seguir usándola, vuelve a pulsar Run desde el Mac.

La app suena aunque el interruptor de silencio esté activado, como un audiolibro. En la pantalla de bloqueo puedes pausar, seguir, cambiar la velocidad y saltar 15 segundos. Si todavía no hay MP3, usa la voz en español del dispositivo. Si no oyes español, descárgala en Ajustes → Accesibilidad → Contenido leído → Voces.

## Generar la narración con ElevenLabs

El generador no forma parte de la app. Usa solo la biblioteca estándar de Python. La clave no se guarda en el repositorio: se lee de `ELEVENLABS_API_KEY`.

1. Elige una voz en ElevenLabs y copia su identificador.
2. Pégalo en `brand.json`, en `elevenlabs.voiceId`. El modelo ya es `eleven_v3`. No pongas la clave en ese archivo.
3. Estima el costo, sin gastar:

```bash
cd aprende
python3 scripts/generate_audio.py
```

El script imprime los caracteres de cada guion y el total. La estimación es 1 crédito por carácter Unicode del texto que se enviaría. Lo que ya está en caché, con el mismo guion, modelo y voz, sale en 0.

4. Cuando el número te cuadre:

```bash
export ELEVENLABS_API_KEY="tu-clave"
python3 scripts/generate_audio.py --yes
```

Sin `--yes` no hay llamada a la API. Los MP3 quedan en `Sources/AprendeCore/Resources/Audio/` y la caché, en `aprende/.audio-cache/` (esa caché no se versiona). Vuelve a compilar la app para que el audio entre en el paquete. Si falta un MP3, esa lección usa la voz del dispositivo.

Para una sola lección:

```bash
python3 scripts/generate_audio.py --lesson como-se-hace-una-ley
python3 scripts/generate_audio.py --lesson como-se-hace-una-ley --yes
```

## Cómo agregar una lección

1. Abre `Sources/AprendeCore/Resources/Content/ecuador-publico.json`, o crea otro curso y anótalo en `Content/manifest.json`.
2. Añade un objeto dentro de `units[].lessons` con `id` (minúsculas, números y guiones), `title`, `summary`, `script`, `sources` y `questions`.
3. El guion, leído a 140 palabras por minuto, tiene que durar entre 3 y 6 minutos (entre 420 y 840 palabras). `swift test` lo rechaza si no.
4. Cada pregunta es `multipleChoice`, `trueFalse`, `order` o `fillBlank`, con `explanation`. Las respuestas del espacio en blanco ignoran mayúsculas y tildes.
5. El orden del arreglo es el camino: la primera lección está abierta y cada una abre la siguiente cuando se aprueba con al menos tres de cuatro. Una figura opcional, en `figures`, puede ser `chart`, `sketch`, `photo` o `calculator`, y tiene que existir en `Resources/Data` o en `credits.json`.
6. Corre `swift test`. Si quieres voz grabada, usa el generador de arriba.
7. Un curso nuevo lleva `"access": "free"` o `"access": "premium"`. En esta versión solo se publica lo `free`. Un curso `premium` queda cerrado hasta que StoreKit confirme la compra, y hoy no hay productos.

Para cambiar el nombre de la app, edita `appName` en `brand.json` y corre `./scripts/setup.sh`. No lo escribas en las pantallas: la interfaz lo lee de ese archivo.

## Privacidad

No hay cuenta, ni backend, ni analítica, ni rastreo. La racha, la experiencia y los repasos se guardan en el dispositivo con SwiftData. `App/PrivacyInfo.xcprivacy` declara que no se rastrea y que no se recolectan datos. La cámara del iPhone, si la autorizas, solo sirve para apoyar el modelo en la mesa.

## Lo que hay que hacer a mano

- Instalar Xcode 26 y XcodeGen, y compilar en un Mac. Aquí no hay Xcode: no se verificó `xcodebuild`, el simulador de iOS, un iPhone ni el simulador de visionOS.
- Probar el mapa sobre una mesa en un iPhone físico. El simulador abre el modelo para girarlo, sin cámara.
- Abrir el esquema LufyAprendeVision en el simulador Apple Vision Pro y entrar al salón. No hace falta un visor.
- No leer el grosor del mapa como metros de altura. No hay modelo SRTM en el paquete.
- Elegir el Personal Team y, si hace falta, otro bundle id.
- Confiar el certificado en el iPhone y activar el modo de desarrollador.
- Revisar los guiones antes de publicarlos. Citan la Constitución, la LOTAIP, la LOSNCP (Registro Oficial suplemento 140, 7 de octubre de 2025) y, en los gráficos, series del Banco Mundial consultadas el 27 de septiembre de 2026. Esas series no son el boletín del Banco Central ni el de deuda pública del Ministerio de Finanzas. Si una norma o una serie cambia, manda el texto nuevo.
- Si más adelante se baja una tabla del INEC o del Ministerio de Finanzas, guardarla en `Resources/Data` con institución, conjunto y fecha. Sin eso, no pongas el número.
- Sustituir `data/app/v1/asamblea.json` y su huella en `manifest.json` por el extracto real de la Asamblea antes de tratar esa URL como el padrón. El esquema está en `data/app/v1/SCHEMA.md` para unificarlo con la otra app. Mientras `example_data` sea verdadero, la pantalla sigue diciendo datos de ejemplo.
- Poner la URL del manifiesto en `brand.json` si la lista debe actualizarse sola.
- Crear la voz en ElevenLabs, poner su id en `brand.json` y decidir si se gastan créditos con `--yes`.
- Descargar una voz española en el iPhone si se va a probar sin MP3.
- Para la App Store, más adelante: ficha, capturas y el equipo de pago de Apple. El manifiesto de privacidad ya dice que no se recolectan datos.
- Para cobrar un curso extra: crear el producto en App Store Connect, poner su id en `brand.json` → `storeKit.premiumProductIds`, marcar el curso como `premium` y volver a compilar. `PremiumStore` compra el primer producto de esa lista y `Entitlements.premium` abre todos los cursos extra. Si más adelante cada curso se vende por separado, el cambio está en esos dos tipos.
