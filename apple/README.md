# Lufy para iPhone, iPad y Mac

App nativa en SwiftUI. Muestra el mismo archivo público que el sitio: investigaciones, línea de fuente, libro (historia, índice y muestra) y la meta de apoyo. El contenido principal es gratis. No hay cuentas, analítica ni rastreadores.

El sitio sigue siendo HTML estático. Esta carpeta no lo modifica. El índice compartido es `data/contenido.json`, en la raíz del repositorio. GitHub Pages lo publica y la app lo descarga. Las páginas HTML no lo leen. La meta de recaudación sigue en `data/meta.json`.

Origen del contenido: https://dimolinari.github.io/lufy-web/

La app no abre sitios oficiales. Una línea de fuente solo abre una copia alojada en Lufy, con su huella SHA-256 y la fecha de archivo, cuando esa copia ya está en el índice. Si `archivo` es null, la línea se lee como texto.

## Requisitos

- Mac con macOS 26 y Xcode 26.
- Destinos: iOS 17 y macOS 14. Swift 6.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), para generar el proyecto. No hace falta commitear el `.xcodeproj`.

Identificadores de relleno, a propósito:

| Campo | Valor |
| --- | --- |
| Nombre mostrado | Lufy |
| Bundle ID | `com.lufy.app` |
| Team ID | `ABCDE12345` |

Hay que sustituir el team (y, si hace falta, el bundle) antes de instalar en un dispositivo. Ver más abajo.

## Generar y abrir

En la Mac:

```bash
brew install xcodegen
cd apple
xcodegen generate
open Lufy.xcodeproj
```

Pruebas del modelo, sin Xcode (también en Linux):

```bash
cd apple
swift test
```

El paquete `LufyCore` es la capa de datos. El target de la app vive en `App/` y depende de ese paquete.

## Instalar en el propio iPhone con un Apple ID gratuito

1. Xcode → Settings → Accounts → añade el Apple ID.
2. Abre el target **Lufy** → Signing & Capabilities.
3. Marca **Automatically manage signing**.
4. En Team elige **Personal Team**. El valor `ABCDE12345` de `project.yml` no firma nada: es un relleno. Para que sobreviva a `xcodegen generate`, cámbialo en `apple/project.yml` (`DEVELOPMENT_TEAM`) por el identificador de tu equipo y vuelve a generar. El equipo personal se ve en Xcode, en la misma pantalla de firma, como un ID de diez caracteres.
5. Si Xcode dice que `com.lufy.app` no está disponible, cambia `PRODUCT_BUNDLE_IDENTIFIER` en `project.yml` (por ejemplo `com.lufy.app.local`) y genera otra vez. El nombre visible sigue siendo Lufy.
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

## Privacidad

No hay cuentas, analítica, anuncios ni SDKs de terceros. Solo frameworks de Apple. La app no recoge datos. Compartir usa la hoja del sistema y el destino es una página de Lufy.
