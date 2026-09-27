# Lufy para iPhone, iPad y Mac

App nativa en SwiftUI. Muestra el mismo contenido que el sitio: hilos de datos públicos, la línea de fuente de cada cifra, el libro (historia, contenido y muestra, nunca el texto completo) y la página de apoyo. No es un WebView.

El índice compartido con el sitio es `data/contenido.json`. La meta de apoyo sigue en `data/meta.json`. La app los descarga de https://dimolinari.github.io/lufy-web/ (la constante `OrigenPublico.sitio`), los guarda en el dispositivo y, si no hay red, usa la copia incluida en el paquete. Esa dirección es el sitio público; la interfaz no muestra un nombre de persona.

## Qué hace falta en el Mac

- macOS 26
- Xcode 26
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.42 o posterior
- Una Apple ID (gratis para instalar en el propio iPhone; el programa de pago solo hace falta para TestFlight y App Store)

Identificadores de relleno, a propósito:

| Campo | Valor |
| --- | --- |
| Nombre | Lufy |
| Bundle ID | `com.lufy.app` |
| Team ID | `0000000000` |

Hay que sustituir el team en Xcode antes de instalar. Si el bundle ID ya está registrado por otra cuenta, cámbialo en `project.yml` (`PRODUCT_BUNDLE_IDENTIFIER`) y vuelve a generar el proyecto.

## Generar y abrir

```bash
brew install xcodegen
cd apple
xcodegen generate
open Lufy.xcodeproj
```

El `.xcodeproj` no se versiona: se regenera con esas dos órdenes. Destinos: iPhone, iPad (iOS 17) y Mac (macOS 14). Swift 6.

En el esquema **Lufy**, elige un simulador o tu Mac y pulsa Run. La firma de desarrollo usa el team que selecciones.

## Instalar en el propio iPhone con una Apple ID gratuita

1. En el iPhone: Ajustes → Privacidad y seguridad → Modo de desarrollador, y actívalo. El teléfono se reinicia.
2. Conecta el iPhone al Mac y, si lo pide, confía en el ordenador.
3. Xcode → Settings → Accounts → añade tu Apple ID.
4. Abre el proyecto generado. Target **Lufy** → Signing & Capabilities.
5. Marca *Automatically manage signing*. En Team elige tu equipo personal (tu nombre). Xcode sustituye el team `0000000000`.
6. Si Xcode dice que `com.lufy.app` no se puede registrar, cambia el bundle ID en `project.yml`, corre `xcodegen generate` otra vez y vuelve a elegir el team.
7. Arriba, elige el iPhone como destino y pulsa Run.
8. En el iPhone: Ajustes → General → VPN y gestión de dispositivos → confía en el certificado de desarrollador.
9. Un perfil gratuito caduca a los 7 días. Para seguir abriendo la app, vuelve a pulsar Run desde Xcode.

Esa instalación no pasa por TestFlight ni por la App Store.

## TestFlight y App Store

Hace falta el Apple Developer Program (de pago), un Team ID real y un bundle ID único. En Xcode: Product → Archive, luego Distribute App. En App Store Connect la ficha de privacidad es «datos no recopilados»: la app no tiene cuentas, analítica ni rastreadores. `PrivacyInfo.xcprivacy` declara lo mismo. El cifrado es solo HTTPS (`ITSAppUsesNonExemptEncryption` = NO).

### El enlace de Ko-fi

Un solo interruptor: `Ajustes.muestraEnlacesKoFi` en `Sources/LufyCore/Ajustes.swift`.

- **Compilaciones locales: `true`.** Aparecen el aporte, la compra del libro y la muestra. La compra ocurre en Ko-fi. Lufy no cobra dentro de la app y no pide datos.
- **App Store: léelo antes de archivar.** La pauta 3.1.1 restringe los enlaces a comprar un bien digital fuera de la app. Quien publica está en Estados Unidos, y esas reglas han cambiado y pueden volver a cambiar. Para una versión que no dependa de un enlace externo, pon el interruptor en `false` y regenera. Con `false` la app sigue mostrando la historia, el contenido y la descripción de la muestra; no muestra el enlace. No hay compra dentro de la app en esta versión.

No se añaden entitlements de External Purchase Link. En el Mac el sandbox solo permite salir a la red como cliente.

## Contenido

```bash
sh apple/scripts/sincronizar-indice.sh
```

Eso copia `data/contenido.json`, `data/meta.json` y el CSV del hilo a `apple/Sources/LufyCore/Resources/`. Los tests fallan si las copias no son idénticas. El HTML del sitio no lee el índice: las páginas siguen siendo estáticas. Cuando cambie una página, hay que actualizar el índice a mano y correr el script.

La línea de fuente abre la copia archivada en Lufy solo si el índice trae `ruta`, `sha256` y `archivado`. Hoy esas copias todavía no están en el repositorio, así que la línea se lee como texto. No se inventa la huella y no se enlaza un sitio oficial. Cuando una copia exista, la app la descarga, calcula la SHA-256 y no muestra el archivo si no coincide. El CSV del hilo es una tabla derivada publicada por Lufy: se incluye para leerla sin red la primera vez, y no se presenta como copia archivada.

El icono provisional sale del dibujo de `favicon.svg`:

```bash
python3 apple/scripts/generar-icono.py
```

Los PNG ya están en el catálogo. Hace falta Pillow (`python3-pil` o `pip install pillow`) solo si se regeneran.

## Pruebas que sí corren sin Xcode

El modelo, el decodificador, la política de enlaces y la huella viven en el paquete `LufyCore`.

```bash
cd apple
swift test
```

En esta máquina (Linux, Swift 6.2) esa orden es la verificación. No hay Xcode: la app SwiftUI no se compiló aquí. En el Mac, después de `xcodegen generate`, conviene un Run en simulador de iPhone, en iPad y en My Mac.

## Privacidad

Sin cuentas, sin analítica, sin rastreadores y sin SDK de terceros. Solo frameworks de Apple. La app pide el índice y, cuando existan, las copias archivadas, al sitio público de Lufy. Con el interruptor encendido, Ko-fi es el único otro sitio.
