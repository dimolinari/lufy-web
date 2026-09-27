import Foundation
import Observation
import LufyCore

/// Descarta redirecciones que salgan del sitio de Lufy.
final class RedLufy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        guard let origen = task.originalRequest?.url,
              let destino = request.url,
              origen.scheme == "https",
              destino.scheme == "https",
              origen.host?.lowercased() == destino.host?.lowercased() else {
            return nil
        }
        return request
    }
}

/// Carga el índice público: primero la copia incluida, luego la guardada
/// en el dispositivo y, si hay red, la publicada. El origen queda fijado
/// por la copia incluida, para que un JSON remoto no cambie los enlaces.
@MainActor
@Observable
final class CatalogoTienda {
    private(set) var catalogo: Catalogo?
    private(set) var meta: MetaRecaudacion?
    private(set) var origenCatalogo: OrigenCarga?
    private(set) var origenMeta: OrigenCarga?
    private(set) var actualizando = false

    private let sesion: URLSession
    private let red: RedLufy
    private var origenPin: String?
    private let topeBytes = 2_097_152

    init() {
        let red = RedLufy()
        self.red = red
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 25
        config.waitsForConnectivity = false
        config.httpAdditionalHeaders = [
            "User-Agent": "LufyApp/1.0",
            "Accept": "application/json",
        ]
        sesion = URLSession(configuration: config, delegate: red, delegateQueue: nil)
        aplicarLocal()
    }

    func actualizar() async {
        guard !actualizando, let pin = origenPin else { return }
        actualizando = true
        defer { actualizando = false }
        let cliente = sesion
        async let remotoCatalogo = Self.bajar(
            sesion: cliente,
            ruta: "data/contenido.json",
            pin: pin,
            topeBytes: topeBytes
        )
        async let remotoMeta = Self.bajar(
            sesion: cliente,
            ruta: "data/meta.json",
            pin: pin,
            topeBytes: topeBytes
        )
        let (datosCatalogo, datosMeta) = await (remotoCatalogo, remotoMeta)
        if let datosCatalogo, Self.aceptaCatalogo(datosCatalogo, pin: pin) {
            catalogo = try? CatalogoDecodificador.catalogo(datos: datosCatalogo)
            origenCatalogo = .red
            Self.guardar("contenido.json", datosCatalogo)
        }
        if let datosMeta, (try? CatalogoDecodificador.meta(datos: datosMeta)) != nil {
            meta = try? CatalogoDecodificador.meta(datos: datosMeta)
            origenMeta = .red
            Self.guardar("meta.json", datosMeta)
        }
    }

    private func aplicarLocal() {
        guard let paquete = Self.leerPaquete("contenido"),
              let pin = (try? CatalogoDecodificador.catalogo(datos: paquete))?.origen else {
            return
        }
        origenPin = pin
        let cache = Self.leerCache("contenido.json")
        if let elegido = ResolucionContenido.elegir(
            red: nil,
            cache: cache,
            paquete: paquete,
            acepta: { Self.aceptaCatalogo($0, pin: pin) }
        ) {
            catalogo = try? CatalogoDecodificador.catalogo(datos: elegido.datos)
            origenCatalogo = elegido.origen
        }

        let paqueteMeta = Self.leerPaquete("meta") ?? Data()
        let cacheMeta = Self.leerCache("meta.json")
        if let elegido = ResolucionContenido.elegir(
            red: nil,
            cache: cacheMeta,
            paquete: paqueteMeta,
            acepta: { (try? CatalogoDecodificador.meta(datos: $0)) != nil }
        ) {
            meta = try? CatalogoDecodificador.meta(datos: elegido.datos)
            origenMeta = elegido.origen
        }
    }

    private static func aceptaCatalogo(_ datos: Data, pin: String) -> Bool {
        guard let catalogo = try? CatalogoDecodificador.catalogo(datos: datos) else { return false }
        return (try? catalogo.validarIntegridad(json: datos, origenEsperado: pin)) != nil
    }

    private static func bajar(sesion: URLSession, ruta: String, pin: String, topeBytes: Int) async -> Data? {
        guard let url = PoliticaEnlaces.urlLufy(origen: pin, ruta: ruta),
              let raiz = URL(string: PoliticaEnlaces.normalizarOrigen(pin) ?? pin) else {
            return nil
        }
        var pedido = URLRequest(url: url)
        pedido.timeoutInterval = 20
        do {
            let (datos, respuesta) = try await sesion.data(for: pedido)
            guard let http = respuesta as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let final = respuesta.url, PoliticaEnlaces.esDestinoLufy(final, origen: raiz) else { return nil }
            guard datos.count <= topeBytes else { return nil }
            return datos
        } catch {
            return nil
        }
    }

    private static func leerPaquete(_ nombre: String) -> Data? {
        guard let url = Bundle.main.url(forResource: nombre, withExtension: "json") else { return nil }
        return try? Data(contentsOf: url)
    }

    private static func archivoCache(_ nombre: String) -> URL? {
        do {
            let base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let carpeta = base.appendingPathComponent("Lufy", isDirectory: true)
            try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
            return carpeta.appendingPathComponent(nombre)
        } catch {
            return nil
        }
    }

    private static func leerCache(_ nombre: String) -> Data? {
        guard let url = archivoCache(nombre) else { return nil }
        return try? Data(contentsOf: url)
    }

    private static func guardar(_ nombre: String, _ datos: Data) {
        guard let url = archivoCache(nombre) else { return }
        try? datos.write(to: url, options: .atomic)
    }
}
