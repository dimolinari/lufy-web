import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum OrigenCarga: String, Sendable, Equatable {
    case red
    case cache
    case empaquetado
}

public enum ResultadoContenido: Sendable, Equatable {
    case listo(ContenidoLufy, OrigenCarga)
    case imposible(String)
}

public enum ResultadoMeta: Sendable, Equatable {
    case valor(MetaRecaudacion, OrigenCarga)
    case fallo(String)
}

public struct Carga: Sendable, Equatable {
    public var contenido: ResultadoContenido
    public var meta: ResultadoMeta
}

public enum ClavesCache {
    public static let contenido = "contenido.json"
    public static let meta = "meta.json"
}

public protocol LectorRed: Sendable {
    func leer(_ url: URL) async throws -> Data
}

public protocol AlmacenLocal: Sendable {
    func leer(_ clave: String) async -> Data?
    func escribir(_ clave: String, datos: Data) async
}

public struct RedURLSession: LectorRed {
    public init() {}

    public func leer(_ url: URL) async throws -> Data {
        var solicitud = URLRequest(url: url)
        solicitud.cachePolicy = .reloadIgnoringLocalCacheData
        solicitud.timeoutInterval = 25
        solicitud.setValue("application/json", forHTTPHeaderField: "Accept")
        let (datos, respuesta) = try await URLSession.shared.data(for: solicitud)
        guard let http = respuesta as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ErrorContenido.red
        }
        return datos
    }
}

public actor AlmacenEnMemoria: AlmacenLocal {
    private var cajas: [String: Data] = [:]

    public init() {}

    public func leer(_ clave: String) -> Data? {
        cajas[clave]
    }

    public func escribir(_ clave: String, datos: Data) {
        cajas[clave] = datos
    }
}

public actor AlmacenEnDisco: AlmacenLocal {
    private let carpeta: URL

    public init(carpeta: URL) {
        self.carpeta = carpeta
    }

    public func leer(_ clave: String) -> Data? {
        let url = carpeta.appendingPathComponent(Self.sanitizar(clave))
        return try? Data(contentsOf: url)
    }

    public func escribir(_ clave: String, datos: Data) {
        let url = carpeta.appendingPathComponent(Self.sanitizar(clave))
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        try? datos.write(to: url, options: .atomic)
    }

    private static func sanitizar(_ clave: String) -> String {
        let permitidos = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        let limpia = clave.unicodeScalars.map { permitidos.contains($0) ? Character($0) : "_" }
        let nombre = String(limpia)
        return nombre.isEmpty ? "cache" : nombre
    }
}

public struct CargadorContenido: Sendable {
    public var red: any LectorRed
    public var almacen: any AlmacenLocal
    public var empaquetadoContenido: Data
    public var empaquetadoMeta: Data
    public var urlContenido: URL
    public var urlMeta: URL

    public init(
        red: any LectorRed,
        almacen: any AlmacenLocal,
        empaquetadoContenido: Data,
        empaquetadoMeta: Data,
        urlContenido: URL,
        urlMeta: URL
    ) {
        self.red = red
        self.almacen = almacen
        self.empaquetadoContenido = empaquetadoContenido
        self.empaquetadoMeta = empaquetadoMeta
        self.urlContenido = urlContenido
        self.urlMeta = urlMeta
    }

    public func cargar() async -> Carga {
        async let contenido = resolverContenido()
        async let meta = resolverMeta()
        return await Carga(contenido: contenido, meta: meta)
    }

    private func resolverContenido() async -> ResultadoContenido {
        if let datos = try? await red.leer(urlContenido), let contenido = try? DecodificadorContenido.decodificar(datos) {
            await almacen.escribir(ClavesCache.contenido, datos: datos)
            return .listo(contenido, .red)
        }
        if let datos = await almacen.leer(ClavesCache.contenido), let contenido = try? DecodificadorContenido.decodificar(datos) {
            return .listo(contenido, .cache)
        }
        if let contenido = try? DecodificadorContenido.decodificar(empaquetadoContenido) {
            return .listo(contenido, .empaquetado)
        }
        return .imposible("No se pudo abrir el contenido de Lufy.")
    }

    private func resolverMeta() async -> ResultadoMeta {
        if let datos = try? await red.leer(urlMeta), let meta = try? MetaRecaudacion.decodificar(datos) {
            await almacen.escribir(ClavesCache.meta, datos: datos)
            return .valor(meta, .red)
        }
        if let datos = await almacen.leer(ClavesCache.meta), let meta = try? MetaRecaudacion.decodificar(datos) {
            return .valor(meta, .cache)
        }
        if let meta = try? MetaRecaudacion.decodificar(empaquetadoMeta) {
            return .valor(meta, .empaquetado)
        }
        return .fallo("No se pudo leer la cifra de la meta.")
    }
}
