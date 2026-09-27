# Lufy para iPhone, iPad y Mac

App nativa en SwiftUI. Muestra el mismo archivo público que el sitio: investigaciones, línea de fuente, libro (historia, índice y muestra) y la meta de apoyo. El contenido principal es gratis. No hay cuentas, analítica ni rastreadores.

El sitio sigue siendo HTML estático. Esta carpeta no lo modifica. El índice compartido es `data/contenido.json`, en la raíz del repositorio. GitHub Pages lo publica y la app lo descarga. Las páginas HTML no lo leen. La meta de recaudación sigue en `data/meta.json`.

Origen del contenido: https://dimolinari.github.io/lufy-web/

La app no abre sitios oficiales. Una línea de fuente solo abre una copia alojada en Lufy, con su huella SHA-256 y la fecha de archivo, cuando esa copia ya está en el índice. Si `archivo` es null, la línea se lee como texto.

## Requisitos

- Mac con macOS 26 y Xcode 26.
- Destinos: iOS 17 y macOS 14. Swift 6. `apple/Package.swift` declara esas mismas plataformas. Sin esa lista, SwiftPM compila `LufyCore` para un sistema anterior y Xcode falla (por ejemplo en `TimeZone.gmt`, que pide iOS 16 o macOS 13).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), para generar el proyecto. No hace falta commitear el `.xcodeproj`.

Identificadores de relleno, a propósito:

| Campo | Valor de relleno |
| --- | --- |
| Nombre mostrado | Lufy |
| Bundle ID | `com.lufy.app` |
| Team ID | `ABCDE12345` |

El bundle y el team viven en `apple/Signing.xcconfig`, no en `project.yml`. El de equipo no firma nada. El real no se escribe en el repositorio. Ver más abajo.

## Generar y abrir

En la Mac:

```bash
brew install xcodegen
cd apple
xcodegen generate
open Lufy.xcodeproj
```

Pruebas del modelo, sin abrir la app (también en Linux):

```bash
cd apple
swift test
```

En Xcode, el esquema **LufyCoreTests** (o Product → Test con el esquema Lufy) corre las mismas pruebas en el simulador de iOS o en My Mac. El target de pruebas no lanza la app: solo enlaza `LufyCore`.

El paquete `LufyCore` es la capa de datos. El target de la app vive en `App/` y depende de ese paquete.

## Firma local

`project.yml` no lleva `DEVELOPMENT_TEAM`. El proyecto apunta a `Signing.xcconfig`, y ese archivo incluye, si existe, `Signing.local.xcconfig`. El segundo está en `.gitignore`. Cambiarlo no exige volver a correr `xcodegen`.

```bash
cd apple
cp Signing.local.xcconfig.example Signing.local.xcconfig
```

En el archivo local, descomenta y rellena solo lo que haga falta:

```
LUFY_DEVELOPMENT_TEAM = ABCDE12345
LUFY_BUNDLE_ID_SUFFIX = .local
LUFY_BUNDLE_ID_PREFIX = local.
LUFY_BUNDLE_ID_BASE = com.lufy.app
```

`LUFY_DEVELOPMENT_TEAM` es el identificador de diez caracteres del Personal Team (Xcode → Signing & Capabilities). No lo subas. El bundle queda `prefijo + base + sufijo`. Con el sufijo `.local`, el id es `com.lufy.app.local`. Si no defines prefijo ni sufijo, sigue siendo `com.lufy.app`.

Sin el archivo local, se puede pasar lo mismo al construir:

```bash
xcodebuild -scheme Lufy -destination 'platform=iOS Simulator,name=iPhone 16' \
  LUFY_DEVELOPMENT_TEAM="$LUFY_DEVELOPMENT_TEAM" \
  LUFY_BUNDLE_ID_SUFFIX="${LUFY_BUNDLE_ID_SUFFIX:-}"
```

`DEVELOPMENT_TEAM` y `PRODUCT_BUNDLE_IDENTIFIER` en la línea de `xcodebuild` también pisan el xcconfig. El `.xcodeproj` generado no se versiona.

## Instalar en el propio iPhone con un Apple ID gratuito

1. Xcode → Settings → Accounts → añade el Apple ID.
2. Abre el target **Lufy** → Signing & Capabilities.
3. Marca **Automatically manage signing**.
4. En Team elige **Personal Team**. Si `Signing.local.xcconfig` ya tiene `LUFY_DEVELOPMENT_TEAM`, Xcode lo toma de ahí. El valor `ABCDE12345` del xcconfig versionado es un relleno y no firma. El equipo personal se ve en Xcode, en la misma pantalla de firma, como un ID de diez caracteres. No lo copies a un archivo que vaya a git.
5. Si Xcode dice que `com.lufy.app` no está disponible, pon `LUFY_BUNDLE_ID_SUFFIX = .local` en `Signing.local.xcconfig`. El nombre visible sigue siendo Lufy. Los ids de la capa de pago (apagada) siguen siendo los de relleno `com.lufy.app.suscripcion.mensual` y `com.lufy.app.dossier.ejemplo` hasta que esa capa se encienda.
6. Conecta el iPhone, desbloquéalo y confía en el ordenador.
7. En el iPhone: Ajustes → Privacidad y seguridad → Modo de desarrollador → actívalo y reinicia.
8. En Xcode elige el iPhone como destino y pulsa Run.
9. Si el iPhone bloquea la app: Ajustes → General → VPN y gestión de dispositivos → confía en el certificado de desarrollador.

Con un Apple ID gratuito el perfil caduca a los 7 días. Para seguir usándola hay que volver a instalarla desde Xcode. Solo corre en dispositivos registrados en esa cuenta. No hay TestFlight.

En el Mac, elige el destino **My Mac** y pulsa Run. No uses Mac Catalyst: el proyecto es multiplataforma (iOS y macOS), con `SUPPORTS_MACCATALYST` en NO.

## TestFlight y App Store

Hace falta el Apple Developer Program (de pago, anual). Con eso:

1. Crea el App ID `com.lufy.app` (o el bundle que hayas elegido) en Certificates, Identifiers & Profiles.
2. En App Store Connect crea la ficha con el nombre **Lufy**.
3. Archive en Xcode (Any iOS Device, y otro archive para Mac si vas a la Mac App Store) y súbelo con Organizer.
4. Etiqueta de privacidad: **Data Not Collected**. El manifiesto `App/PrivacyInfo.xcprivacy` declara que no hay rastreo, ni datos recogidos, ni APIs de razón requerida. La app no usa `UserDefaults` ni caché de URL del sistema.
5. Cifrado: `ITSAppUsesNonExemptEncryption` ya está en false. En App Store Connect responde que no usas cifrado exento.
6. Completa la ficha (categoría referencia, captura de pantalla, texto). El icono de esta versión es un marcador de posición con la balanza del sitio.

La Mac App Store, más adelante, pide sandbox y la capacidad de cliente de red saliente. Esta versión no las activa: sirve para correr desde Xcode. No las enciendas hasta el envío a la Mac App Store.

### Enlace de Ko-fi

`App/Configuracion.swift` tiene un solo interruptor:

```swift
static let mostrarEnlacesKoFi = true
```

En `true`, la app puede abrir Ko-fi (aporte, libro o muestra). En `false`, esos botones no se muestran. El contenido sigue gratis.

Quien publica está en Estados Unidos. La norma 3.1.1 de la App Store restringe los enlaces de compra externa, y el trato cambia por país y por el tipo de bien (un libro digital no es lo mismo que un aporte). Antes de subir el archive a revisión, decide si este interruptor se queda en `true` o pasa a `false`. Si lo dejas en `true` sin el derecho que Apple exija en ese momento, la revisión puede rechazar la app. Las compilaciones locales lo dejan encendido.

La muestra y el libro completo no van dentro de la app. La sección del libro enseña la historia, el índice y el texto público de la muestra.

## Contenido

Al abrir, la app lee `contenido.json` y `meta.json` incluidos en el paquete y fija el origen con el del paquete. Si hay una copia previa en Application Support (`Lufy/`), y esa copia pasa la misma validación, se usa. Después intenta la red (`data/contenido.json` y `data/meta.json` en el origen). Si la red responde bien, sustituye la copia guardada. Si falla, se queda lo que ya se estaba leyendo. La primera vez sin red se usa el paquete.

Un JSON remoto que apunte a otro sitio, o que incluya un enlace fuera de Lufy o de Ko-fi, se descarta. No se sigue una redirección a otro host.

Sellos de un hallazgo, tal cual el sitio: CONFIRMADO, INDICIO, ABIERTO, HIPÓTESIS. OCR es una marca de lectura, no un sello.

Para añadir una investigación no hace falta una versión nueva de la app, mientras `schema` siga en 1 y el hilo use bloques conocidos:

`prosa`, `aviso`, `lista`, `grafico`, `tabla`, `columnas`, `tiempo`, `ficha`, `glosario`, `documentos`, `cambios`.

Un `tipo` desconocido se omite. El resto del hilo se muestra. Subir `schema` sí exige una actualización de la app.

Al cambiar una página o el CSV de campaña, actualiza `data/contenido.json` en el mismo cambio. `swift test` comprueba que las cifras de campaña del índice coinciden con `datos/cne-elecciones-generales-2025.csv`. No inventes una huella SHA-256: deja `archivo` en null hasta que el archivo esté en el repositorio.

## Tarjetas para compartir

Un hallazgo, una cifra, un gráfico o un voto registrado se puede exportar como imagen desde el botón Tarjeta. La hoja de compartir del sistema recibe un PNG de 1080×1920 (historias de X e Instagram). La tarjeta lleva el nombre Lufy, la línea de fuente tal cual está publicada, el enlace a una página de Lufy y un código QR de ese enlace.

Si el ítem tiene sello, la tarjeta muestra exactamente CONFIRMADO, INDICIO, ABIERTO o HIPÓTESIS. Un voto y un gráfico no tienen sello: la tarjeta no inventa uno. El texto es el título, el detalle o el sentido registrado (A favor, En contra, Abstención, Ausente, En blanco). La app no redacta una acusación para la tarjeta. Si el texto publicado no pasa la revisión de palabras, el botón no aparece.

Los perfiles de la Asamblea todavía no tienen página propia. Su QR apunta a la página de Datos de Lufy, que sí existe.

## Capa de pago (apagada)

`App/Configuracion.swift` tiene otro interruptor, además del de Ko-fi:

```swift
static let capaDePagoActiva = false
```

En `false` (el valor de esta versión) la app no esconde nada, no ofrece compras y no pide permiso de avisos. El contenido de base sigue gratis en los dos lados del interruptor.

En `true`, StoreKit 2 ofrece:

- Una suscripción auto-renovable, `com.lufy.app.suscripcion.mensual` (periodo P1M). Quien está suscrito ve los hallazgos con `early_access_until` en el futuro. Quien no, los ve cuando llega esa fecha. Sin fecha, el hallazgo sigue visible. Una fecha ilegible se esconde para quien no está suscrito.
- Avisos, dentro de la app y como notificación local, cuando un perfil, una institución o un tema que la persona sigue recibe un ítem nuevo. El aviso copia el título publicado y, si lo hay, el sello. Un voto no lleva sello. La primera copia del feed no avisa. El permiso se pide solo desde Avisos, con el interruptor encendido y la suscripción activa. No hay push remoto ni entitlement de notificaciones.
- Dossiers descargables. Cada uno es un producto no consumible (`producto` en el feed; el de ejemplo es `com.lufy.app.dossier.ejemplo`). Se baja si hay suscripción o si ese producto ya se compró, y solo cuando `archivo` trae una copia en Lufy. El ejemplo deja `archivo` en null.

Los identificadores son de relleno. Cámbialos en App Store Connect y en `App/TiendaPagos.swift` antes de vender. Hace falta una cuenta de pago del Apple Developer Program: el Apple ID gratuito no vende suscripciones. El esquema de Xcode usa `App/Lufy.storekit` para probar en local, sin tienda real. No enciendas sandbox ni push para este paso.

`early_access_until` es la fecha que obedece la app (día `AAAA-MM-DD` al inicio de ese día UTC, o `AAAA-MM-DDTHH:MM:SSZ`). `diasAccesoAnticipado` (7) y `dias_acceso_anticipado` en `meta.json` son la convención del publicador para calcular esa fecha al generar el feed. Si el hallazgo ya trae la clave, incluso en null, el generador no la pisa.

Los seguimientos y la lista de avisos viven en Application Support (`Lufy/seguimientos/`), no en `UserDefaults`.

## Asamblea y feed diario

La sección Asamblea lista perfiles públicos. El corte que viene en el repositorio es **dato de ejemplo**: los nombres son «Asambleísta Ejemplo 1» y «Asambleísta Ejemplo 2». La app muestra el aviso del feed en una franja. No son integrantes reales. Un voto no es un sello. Los hallazgos, si los hay, solo usan CONFIRMADO, INDICIO, ABIERTO o HIPÓTESIS.

Cada perfil tiene nombre, provincia, circunscripción, partido, bloque, comisiones, período, proyectos, votos con la línea de fuente de la sesión o el acta, y asistencia si el exporte la trae. La foto solo entra si la licencia es `dominio-publico`, `cc0` o `cc-by`; si no, se ven las iniciales. No hay cédula, domicilio, correo, familiares ni montos individuales de declaraciones patrimoniales: el generador rechaza esos campos, un número de 10 dígitos y un correo.

**Solicitar corrección** abre un borrador con el `id` del perfil y `campo: nombre`. La dirección se arma en `App/Configuracion.swift` con un dominio de ejemplo. Cámbiala por el buzón de Lufy antes de publicar.

El feed es genérico. Otra app puede publicar el mismo manifiesto con otro `id` y otros archivos. Lufy usa `id` `lufy` y estos archivos:

| Archivo | Rol |
| --- | --- |
| `data/app/v1/manifest.json` | Lista de archivos, sha256, bytes y `updated_at` |
| `data/app/v1/asamblea.json` | Perfiles |
| `data/app/v1/hallazgos.json` | Hallazgos con sello, tema y `early_access_until` |
| `data/app/v1/dossiers.json` | Fichas de dossier. El archivo sigue en null hasta que Lufy lo publique |
| `data/app/v1/votaciones/<id>.json` | Una votación por archivo |

Al abrir, la app consulta el manifiesto si la última consulta fue hace 24 horas o más (o si todavía no consultó). Solo baja los archivos cuyo sha256 cambió. Si la huella no coincide, se queda con la copia anterior. La pantalla muestra `Actualizado: AAAA-MM-DD`. La primera vez sin red usa la copia incluida en la app.

### Generar el feed

El exporte diario se deja en `data/app/entrada/`. Sin red:

```bash
python3 data/app/generar_feed.py
```

Opciones: `--entrada` y `--salida`. El esquema de esa carpeta y del JSON publicado está en `data/app/README.md`.

## Privacidad

No hay cuentas, analítica, anuncios ni SDKs de terceros. Solo frameworks de Apple (incluida StoreKit 2, inactiva mientras `capaDePagoActiva` esté en false). La app no recoge datos. Compartir usa la hoja del sistema: una página de Lufy, o la imagen de la tarjeta con el enlace a esa página.
