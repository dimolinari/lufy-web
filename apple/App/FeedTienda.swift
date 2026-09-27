import Foundation
import Observation
import LufyCore

/// Baja el feed versionado como mucho una vez al día. Si un archivo no
/// coincide con su sha256, se conserva la copia anterior.
@MainActor
@Observable
final class FeedTienda {
    private(set) var asamblea: IndiceAsamblea?
    private(set) var votaciones: [Votacion] = []
    private(set) var hallazgos: [HallazgoPublico] = []
    private(set) var actualizado: String?
    private(set) var consultando = false

    private let sesion: URLSession
    private let red: RedLufy
    private var origenPin: String?
    private let idEsperado = "lufy"

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
        if let datos = Self.datosSueltos("contenido.json"),
           let catalogo = try? CatalogoDecodificador.catalogo(datos: datos) {
            origenPin = catalogo.origen
            cargarLocal(origen: catalogo.origen)
        }
    }

    func actualizarSiToca(origen: String) async {
        if origenPin != origen {
            origenPin = origen
            cargarLocal(origen: origen)
        }
        guard !consultando else { return }
        guard RitmoFeed.debeConsultar(ultima: Self.leerMarca(), ahora: Date()) else { return }
        consultando = true
        defer { consultando = false }
        let cliente = sesion
        guard let manifiestoDatos = await Self.bajar(
            sesion: cliente,
            origen: origen,
            ruta: "data/app/v1/manifest.json",
            tope: ManifiestoFeed.topeBytes
        ),
            let manifiesto = try? JSONDecoder().decode(ManifiestoFeed.self, from: manifiestoDatos),
            (try? manifiesto.validar()) != nil,
            manifiesto.id == idEsperado,
            let fecha = RitmoFeed.fechaVisible(manifiesto.updatedAt) else {
            return
        }

        var archivos: [String: Data] = [:]
        for archivo in manifiesto.files {
            if let local = copiaBuena(archivo) {
                archivos[archivo.path] = local
                continue
            }
            guard let remoto = await Self.bajar(
                sesion: cliente,
                origen: origen,
                ruta: "data/app/v1/\(archivo.path)",
                tope: archivo.bytes
            ), ManifiestoFeed.coincide(remoto, con: archivo) else {
                return
            }
            archivos[archivo.path] = remoto
        }
        guard let conjunto = Self.conjunto(archivos: archivos, origen: origen) else { return }
        guard Self.guardar(archivos: archivos, manifiesto: manifiestoDatos) else { return }
        Self.guardarMarca(Date())
        aplicar(conjunto, fecha: fecha)
    }

    func votaciones(de identificador: String) -> [(votacion: Votacion, voto: SentidoVoto)] {
        votaciones.compactMap { sesion in
            guard let registro = sesion.votos.first(where: { $0.asambleistaId == identificador }) else { return nil }
            return (sesion, registro.voto)
        }
    }

    func hallazgos(de identificadores: [String]) -> [HallazgoPublico] {
        identificadores.compactMap { id in hallazgos.first { $0.id == id } }
    }

    private func cargarLocal(origen: String) {
        if let carpeta = Self.carpetaV1(),
           let cargado = leer(carpeta: carpeta, origen: origen) {
            aplicar(cargado.conjunto, fecha: cargado.fecha)
            return
        }
        guard let manifiestoDatos = Self.datosPaquete("manifest.json"),
              let manifiesto = try? JSONDecoder().decode(ManifiestoFeed.self, from: manifiestoDatos),
              (try? manifiesto.validar()) != nil,
              manifiesto.id == idEsperado,
              let fecha = RitmoFeed.fechaVisible(manifiesto.updatedAt) else {
            return
        }
        var archivos: [String: Data] = [:]
        for archivo in manifiesto.files {
            guard let datos = Self.datosPaquete(archivo.path), ManifiestoFeed.coincide(datos, con: archivo) else { return }
            archivos[archivo.path] = datos
        }
        guard let conjunto = Self.conjunto(archivos: archivos, origen: origen) else { return }
        aplicar(conjunto, fecha: fecha)
    }

    private func leer(carpeta: URL, origen: String) -> (conjunto: (IndiceAsamblea, IndiceHallazgos, [Votacion]), fecha: String)? {
        let url = carpeta.appendingPathComponent("manifest.json")
        guard let datos = try? Data(contentsOf: url),
              let manifiesto = try? JSONDecoder().decode(ManifiestoFeed.self, from: datos),
              (try? manifiesto.validar()) != nil,
              manifiesto.id == idEsperado,
              let fecha = RitmoFeed.fechaVisible(manifiesto.updatedAt) else {
            return nil
        }
        var archivos: [String: Data] = [:]
        for archivo in manifiesto.files {
            guard let destino = Self.destinoSeguro(carpeta, archivo.path),
                  let bytes = try? Data(contentsOf: destino),
                  ManifiestoFeed.coincide(bytes, con: archivo) else {
                return nil
            }
            archivos[archivo.path] = bytes
        }
        guard let conjunto = Self.conjunto(archivos: archivos, origen: origen) else { return nil }
        return (conjunto, fecha)
    }

    private func copiaBuena(_ archivo: ArchivoFeed) -> Data? {
        if let carpeta = Self.carpetaV1(),
           let destino = Self.destinoSeguro(carpeta, archivo.path),
           let datos = try? Data(contentsOf: destino),
           ManifiestoFeed.coincide(datos, con: archivo) {
            return datos
        }
        if let datos = Self.datosPaquete(archivo.path), ManifiestoFeed.coincide(datos, con: archivo) {
            return datos
        }
        return nil
    }

    private func aplicar(_ conjunto: (IndiceAsamblea, IndiceHallazgos, [Votacion]), fecha: String) {
        asamblea = conjunto.0
        hallazgos = conjunto.1.hallazgos
        votaciones = conjunto.2.sorted { $0.fecha > $1.fecha }
        actualizado = fecha
    }

    private static func conjunto(archivos: [String: Data], origen: String) -> (IndiceAsamblea, IndiceHallazgos, [Votacion])? {
        guard let asamblea = archivos["asamblea.json"], let hallazgos = archivos["hallazgos.json"] else { return nil }
        let sesiones = archivos.keys.filter { $0.hasPrefix("votaciones/") && $0.hasSuffix(".json") }.sorted().compactMap { ruta -> (ruta: String, datos: Data)? in
            guard let datos = archivos[ruta] else { return nil }
            return (ruta, datos)
        }
        return try? ConjuntoAsamblea.validar(
            asamblea: asamblea,
            hallazgos: hallazgos,
            votaciones: sesiones,
            origen: origen
        )
    }

    private static func bajar(sesion: URLSession, origen: String, ruta: String, tope: Int) async -> Data? {
        guard tope > 0, tope <= ManifiestoFeed.topeBytes else { return nil }
        guard let url = PoliticaEnlaces.urlLufy(origen: origen, ruta: ruta),
              let raiz = URL(string: PoliticaEnlaces.normalizarOrigen(origen) ?? origen) else {
            return nil
        }
        var pedido = URLRequest(url: url)
        pedido.timeoutInterval = 20
        do {
            let (datos, respuesta) = try await sesion.data(for: pedido)
            guard let http = respuesta as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let final = respuesta.url, PoliticaEnlaces.esDestinoLufy(final, origen: raiz) else { return nil }
            guard datos.count <= tope else { return nil }
            return datos
        } catch {
            return nil
        }
    }

    private static func datosSueltos(_ nombre: String) -> Data? {
        let ns = nombre as NSString
        guard let url = Bundle.main.url(forResource: ns.deletingPathExtension, withExtension: ns.pathExtension) else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    private static func datosPaquete(_ relativo: String) -> Data? {
        let ns = relativo as NSString
        let archivo = ns.lastPathComponent as NSString
        let carpeta = ns.deletingLastPathComponent
        let sub = carpeta.isEmpty ? "v1" : "v1/\(carpeta)"
        if let url = Bundle.main.url(
            forResource: archivo.deletingPathExtension,
            withExtension: archivo.pathExtension,
            subdirectory: sub
        ) {
            return try? Data(contentsOf: url)
        }
        return Bundle.main.url(
            forResource: archivo.deletingPathExtension,
            withExtension: archivo.pathExtension,
            subdirectory: "v1"
        ).flatMap { try? Data(contentsOf: $0) }
    }

    private static func carpetaFeed() -> URL? {
        do {
            let base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let carpeta = base.appendingPathComponent("Lufy/feed", isDirectory: true)
            try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
            return carpeta
        } catch {
            return nil
        }
    }

    private static func carpetaV1() -> URL? {
        guard let feed = carpetaFeed() else { return nil }
        let carpeta = feed.appendingPathComponent("v1", isDirectory: true)
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        return carpeta
    }

    private static func destinoSeguro(_ carpeta: URL, _ relativo: String) -> URL? {
        guard ManifiestoFeed.rutaSegura(relativo) else { return nil }
        let destino = carpeta.appendingPathComponent(relativo)
        let base = carpeta.standardizedFileURL.path
        let final = destino.standardizedFileURL.path
        let prefijo = base.hasSuffix("/") ? base : base + "/"
        guard final.hasPrefix(prefijo) else { return nil }
        return destino
    }

    private static func guardar(archivos: [String: Data], manifiesto: Data) -> Bool {
        guard let carpeta = carpetaV1() else { return false }
        for (ruta, datos) in archivos {
            guard let destino = destinoSeguro(carpeta, ruta) else { return false }
            do {
                try FileManager.default.createDirectory(
                    at: destino.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try datos.write(to: destino, options: .atomic)
            } catch {
                return false
            }
        }
        do {
            try manifiesto.write(to: carpeta.appendingPathComponent("manifest.json"), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private static func leerMarca() -> Date? {
        guard let url = carpetaFeed()?.appendingPathComponent("ultima-consulta.txt"),
              let texto = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return RitmoFeed.interpretarMarca(texto.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func guardarMarca(_ fecha: Date) {
        guard let url = carpetaFeed()?.appendingPathComponent("ultima-consulta.txt") else { return }
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let partes = calendario.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fecha)
        guard let anio = partes.year, let mes = partes.month, let dia = partes.day,
              let hora = partes.hour, let minuto = partes.minute, let segundo = partes.second else {
            return
        }
        let texto = String(format: "%04d-%02d-%02dT%02d:%02d:%02dZ", anio, mes, dia, hora, minuto, segundo)
        try? texto.write(to: url, atomically: true, encoding: .utf8)
    }
}
