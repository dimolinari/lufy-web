import LufyCore
import PDFKit
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum DescargaLufy {
    enum Resultado: Sendable {
        case datos(Data)
        case rechazada
        case fallo
    }

    static func leer(ruta: String) async -> Resultado {
        guard let url = PoliticaEnlaces.urlLufy(ruta: ruta) else { return .rechazada }
        do {
            var solicitud = URLRequest(url: url)
            solicitud.timeoutInterval = 40
            solicitud.cachePolicy = .reloadIgnoringLocalCacheData
            let (datos, respuesta) = try await URLSession.shared.data(for: solicitud)
            guard let http = respuesta as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let final = http.url,
                  PoliticaEnlaces.esLufy(final),
                  !datos.isEmpty
            else { return .rechazada }
            return .datos(datos)
        } catch {
            return .fallo
        }
    }
}

enum CacheArchivos {
    static func leer(nombre: String) -> Data? {
        guard let url = archivo(nombre) else { return nil }
        return try? Data(contentsOf: url)
    }

    static func escribir(nombre: String, datos: Data) {
        guard let url = archivo(nombre) else { return }
        try? datos.write(to: url, options: .atomic)
    }

    static func borrar(nombre: String) {
        guard let url = archivo(nombre) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func archivo(_ nombre: String) -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let carpeta = base.appendingPathComponent("Lufy/copias", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        let limpio = nombre.map { caracter -> Character in
            caracter.isLetter || caracter.isNumber ? caracter : "_"
        }
        let seguro = String(limpio)
        guard !seguro.isEmpty else { return nil }
        return carpeta.appendingPathComponent(seguro)
    }
}

struct VisorArchivo: View {
    let referencia: ReferenciaArchivo
    @State private var estado: Estado = .cargando
    @Environment(\.colorScheme) private var scheme

    private enum Estado {
        case cargando
        case listo(Data)
        case distinta
        case invalida
        case rechazada
        case sinRed
    }

    var body: some View {
        Group {
            switch estado {
            case .cargando:
                ProgressView("Comprobando la copia de Lufy…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .listo(let datos):
                documento(datos)
            case .distinta:
                aviso(
                    "La huella no coincide",
                    "Lufy no muestra este archivo. La copia descargada no tiene la SHA-256 publicada."
                )
            case .invalida:
                aviso(
                    "La huella publicada no es válida",
                    "Lufy no muestra el archivo hasta que el índice traiga una SHA-256 completa."
                )
            case .rechazada:
                aviso(
                    "Esa copia no está en Lufy",
                    "La app solo abre documentos alojados por Lufy."
                )
            case .sinRed:
                aviso(
                    "No hay copia guardada",
                    "Hace falta conexión la primera vez que se abre este documento. Después queda en el dispositivo."
                )
            }
        }
        .fondoLufy()
        .barraLufy(referencia.documento)
        .task { await abrir() }
    }

    private func documento(_ datos: Data) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(referencia.institucion)
                    .font(.subheadline.weight(.semibold))
                Text("\(referencia.documento) · \(referencia.fecha)")
                    .font(.footnote)
                Text("Copia en Lufy · SHA-256 \(huellaAgrupada(referencia.sha256)) · archivada el \(referencia.archivado)")
                    .font(.caption)
                    .textSelection(.enabled)
                Text("La huella coincide. Lufy no abre el sitio de origen.")
                    .font(.caption)
            }
            .foregroundStyle(Paleta.texto(scheme))
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Paleta.superficie(scheme))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Copia archivada por Lufy. \(referencia.institucion). \(referencia.documento). Archivada el \(referencia.archivado). La huella coincide.")

            if datos.starts(with: Data("%PDF".utf8)) {
                VisorPDF(datos: datos)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Documento PDF de la copia archivada.")
            } else if let texto = String(data: datos, encoding: .utf8) {
                ScrollView {
                    Text(texto)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            } else {
                VistaVacia(
                    titulo: "La copia está guardada",
                    detalle: "La huella coincide. Este formato no se dibuja dentro de la app."
                )
            }
        }
    }

    private func aviso(_ titulo: String, _ detalle: String) -> some View {
        VistaVacia(titulo: titulo, detalle: detalle)
    }

    private func abrir() async {
        let clave = referencia.sha256.lowercased()
        if let cache = CacheArchivos.leer(nombre: clave),
           HuellaSHA256.veredicto(datos: cache, esperada: referencia.sha256) == .coincide {
            estado = .listo(cache)
            return
        }
        CacheArchivos.borrar(nombre: clave)
        switch await DescargaLufy.leer(ruta: referencia.ruta) {
        case .datos(let datos):
            switch HuellaSHA256.veredicto(datos: datos, esperada: referencia.sha256) {
            case .coincide:
                CacheArchivos.escribir(nombre: clave, datos: datos)
                estado = .listo(datos)
            case .distinta:
                estado = .distinta
            case .invalida:
                estado = .invalida
            }
        case .rechazada:
            estado = .rechazada
        case .fallo:
            estado = .sinRed
        }
    }
}

struct VisorAdjunto: View {
    let hiloID: String
    @Environment(ModeloApp.self) private var modelo
    @Environment(\.colorScheme) private var scheme
    @State private var texto: String?
    @State private var fallo: String?

    var body: some View {
        Group {
            if let hilo = modelo.contenido?.hilos.first(where: { $0.id == hiloID }), let adjunto = hilo.adjunto {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(adjunto.titulo)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Archivo publicado por Lufy. No es una copia archivada del documento oficial y no tiene SHA-256 publicada.")
                            .font(.footnote)
                            .foregroundStyle(Paleta.suave(scheme))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if let texto {
                        ScrollView([.horizontal, .vertical]) {
                            Text(texto)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(16)
                        }
                        .accessibilityLabel("Tabla de cifras publicada por Lufy.")
                    } else if let fallo {
                        VistaVacia(titulo: "El archivo no está disponible", detalle: fallo)
                    } else {
                        ProgressView("Abriendo el archivo de Lufy…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .task { await abrir(adjunto) }
            } else {
                VistaVacia(titulo: "Ese archivo no está en el índice", detalle: "Actualiza el contenido cuando tengas conexión.")
            }
        }
        .fondoLufy()
        .barraLufy("Archivo de Lufy")
    }

    private func abrir(_ adjunto: Adjunto) async {
        let clave = "adjunto-\(adjunto.ruta)"
        switch await DescargaLufy.leer(ruta: adjunto.ruta) {
        case .datos(let datos):
            guard let texto = String(data: datos, encoding: .utf8) else {
                fallo = "Lufy no muestra este archivo porque no es texto."
                return
            }
            CacheArchivos.escribir(nombre: clave, datos: datos)
            self.texto = texto
        case .rechazada:
            usarGuardado(clave, adjunto, siFalta: "La app solo abre archivos alojados por Lufy.")
        case .fallo:
            usarGuardado(clave, adjunto, siFalta: "Sin conexión, y esta copia no está guardada en el dispositivo.")
        }
    }

    private func usarGuardado(_ clave: String, _ adjunto: Adjunto, siFalta: String) {
        if let cache = CacheArchivos.leer(nombre: clave), let texto = String(data: cache, encoding: .utf8) {
            self.texto = texto
            return
        }
        usarEmpaquetado(adjunto, siFalta: siFalta)
    }

    private func usarEmpaquetado(_ adjunto: Adjunto, siFalta: String) {
        guard let datos = ContenidoEmpaquetado.datosAdjunto(ruta: adjunto.ruta),
              let texto = String(data: datos, encoding: .utf8)
        else {
            fallo = siFalta
            return
        }
        self.texto = texto
    }
}

#if os(iOS)
struct VisorPDF: UIViewRepresentable {
    let datos: Data

    func makeUIView(context: Context) -> PDFView {
        vista()
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document == nil {
            uiView.document = PDFDocument(data: datos)
        }
    }
}
#else
struct VisorPDF: NSViewRepresentable {
    let datos: Data

    func makeNSView(context: Context) -> PDFView {
        vista()
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document == nil {
            nsView.document = PDFDocument(data: datos)
        }
    }
}
#endif

@MainActor
private func vista() -> PDFView {
    let vista = PDFView()
    vista.autoScales = true
    vista.displayMode = .singlePageContinuous
    vista.displayDirection = .vertical
    return vista
}

func huellaAgrupada(_ huella: String) -> String {
    stride(from: 0, to: huella.count, by: 4).map { inicio in
        let desde = huella.index(huella.startIndex, offsetBy: inicio)
        let hasta = huella.index(desde, offsetBy: min(4, huella.distance(from: desde, to: huella.endIndex)))
        return String(huella[desde..<hasta])
    }.joined(separator: " ")
}
