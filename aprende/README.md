# Lufy Aprende

App nativa para aprender, en voz alta, cómo funciona lo público en el Ecuador. Cada lección es un audiolibro corto, de tres a seis minutos. Después hay unas preguntas. Si fallas alguna, vuelve al día siguiente.

El nombre visible de la app está en un solo archivo: `Sources/AprendeCore/Resources/brand.json`. Hoy dice **Lufy Aprende**. La lógica de cursos, puntajes, racha y repaso vive en el paquete Swift `AprendeCore`, sin red y sin cuenta.

Esta carpeta no toca la web de Lufy.

## Qué hay aquí

- `Sources/AprendeCore`: contenido, puntuación, XP, racha, repaso espaciado y la regla de cursos gratis o de pago.
- `Tests/AprendeCoreTests`: pruebas que corren con `swift test`, también en Linux.
- `App`: interfaz SwiftUI para iOS 17 y macOS 14.
- `project.yml`: definición del proyecto para XcodeGen.
- `scripts/generate_audio.py`: voz grabada opcional, con ElevenLabs. La app no lo necesita para funcionar.
- `Sources/AprendeCore/Resources/Data`: series y el esquema de provincias, cada uno con su fuente.
- `Sources/AprendeCore/Resources/Media`: cuatro fotos pequeñas y `credits.json`.
- `scripts/setup.sh`: escribe el nombre en el proyecto de Xcode y lo genera.

La versión 1 es gratis. El camino **Gobierno y lo público** trae la unidad completa: cinco lecciones (cómo se hace una ley, cómo compra el Estado, cómo se lee un contrato, cómo se pide información y una primera mirada a las eras). Los demás caminos publican una lección de muestra, y Finanzas publica dos:

- Historia por eras.
- Geografía y regiones.
- Provincias.
- Naturaleza y biodiversidad.
- Cultura y pueblos.
- Economía.
- Finanzas, con un aviso de que no es asesoría ni una recomendación de compra.

Hay gráficos para recorrer con el dedo, un esquema de provincias y una calculadora de interés compuesto. Las series numéricas salen del Banco Mundial y llevan institución, indicador y fecha. Si un archivo tuviera `exampleData: true`, la pantalla muestra **DATOS DE EJEMPLO**. Las fotos son pocas, de Wikimedia Commons, con autor y licencia en `Resources/Media/credits.json`.

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

El identificador de paquete de partida es `com.lufy.aprende`. El team de partida es `XXXXXXXXXX`. Los dos son marcadores. Cámbialos en `brand.json` y vuelve a correr `./scripts/setup.sh` antes de firmar.

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

No hay cuenta, ni backend, ni analítica, ni rastreo. La racha, la experiencia y los repasos se guardan en el dispositivo con SwiftData. `App/PrivacyInfo.xcprivacy` declara que no se rastrea y que no se recolectan datos.

## Lo que hay que hacer a mano

- Instalar Xcode 26 y XcodeGen, y compilar en un Mac. Aquí no hay Xcode: no se verificó `xcodebuild`, el simulador ni un iPhone.
- Elegir el Personal Team y, si hace falta, otro bundle id.
- Confiar el certificado en el iPhone y activar el modo de desarrollador.
- Revisar los guiones antes de publicarlos. Citan la Constitución, la LOTAIP, la LOSNCP (Registro Oficial suplemento 140, 7 de octubre de 2025) y, en los gráficos, series del Banco Mundial consultadas el 27 de septiembre de 2026. Esas series no son el boletín del Banco Central ni el de deuda pública del Ministerio de Finanzas. Si una norma o una serie cambia, manda el texto nuevo.
- Si más adelante se baja una tabla del INEC o del Ministerio de Finanzas, guardarla en `Resources/Data` con institución, conjunto y fecha. Sin eso, no pongas el número.
- Crear la voz en ElevenLabs, poner su id en `brand.json` y decidir si se gastan créditos con `--yes`.
- Descargar una voz española en el iPhone si se va a probar sin MP3.
- Para la App Store, más adelante: ficha, capturas y el equipo de pago de Apple. El manifiesto de privacidad ya dice que no se recolectan datos.
- Para cobrar un curso extra: crear el producto en App Store Connect, poner su id en `brand.json` → `storeKit.premiumProductIds`, marcar el curso como `premium` y volver a compilar. `PremiumStore` compra el primer producto de esa lista y `Entitlements.premium` abre todos los cursos extra. Si más adelante cada curso se vende por separado, el cambio está en esos dos tipos.
