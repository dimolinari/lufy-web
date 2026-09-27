import Foundation
import XCTest
import LufyCore

final class FeedTests: XCTestCase {
    private let origen = "https://archivo.example/lufy-web/"

    func testHuellaConocida() {
        XCTAssertEqual(Huella.sha256(Data()), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertEqual(Huella.sha256(Data("abc".utf8)), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let largo = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
        XCTAssertEqual(
            Huella.sha256(Data(largo.utf8)),
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
        )
    }

    func testConsultaComoMuchoUnaVezAlDia() {
        let ahora = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(RitmoFeed.debeConsultar(ultima: nil, ahora: ahora))
        XCTAssertFalse(RitmoFeed.debeConsultar(ultima: ahora.addingTimeInterval(-3_600), ahora: ahora))
        XCTAssertTrue(RitmoFeed.debeConsultar(ultima: ahora.addingTimeInterval(-86_400), ahora: ahora))
        XCTAssertTrue(RitmoFeed.debeConsultar(ultima: ahora.addingTimeInterval(30), ahora: ahora))
        let marca = try? XCTUnwrap(RitmoFeed.interpretarMarca("2026-09-27T00:00:00Z"))
        XCTAssertNotNil(marca)
        XCTAssertNil(RitmoFeed.interpretarMarca("2026-09-27"))
        XCTAssertEqual(RitmoFeed.fechaVisible("2026-09-27T00:00:00Z"), "2026-09-27")
    }

    func testRutasYManifiesto() throws {
        XCTAssertTrue(ManifiestoFeed.rutaSegura("asamblea.json"))
        XCTAssertTrue(ManifiestoFeed.rutaSegura("votaciones/vot-ejemplo-1.json"))
        XCTAssertFalse(ManifiestoFeed.rutaSegura("../secreto.json"))
        XCTAssertFalse(ManifiestoFeed.rutaSegura("/asamblea.json"))
        XCTAssertFalse(ManifiestoFeed.rutaSegura("votaciones//a.json"))
        XCTAssertFalse(ManifiestoFeed.rutaSegura("https://archivo.example/a.json"))

        let manifiesto = try cargarManifiesto()
        XCTAssertEqual(manifiesto.id, "lufy")
        XCTAssertEqual(manifiesto.schema, 1)
        XCTAssertNoThrow(try manifiesto.validar())
        let carpeta = feed().appendingPathComponent("v1")
        var hashes: [String: String] = [:]
        for archivo in manifiesto.files {
            let datos = try Data(contentsOf: carpeta.appendingPathComponent(archivo.path))
            XCTAssertTrue(ManifiestoFeed.coincide(datos, con: archivo))
            hashes[archivo.path] = archivo.sha256
        }
        XCTAssertTrue(manifiesto.pendientes(hashesLocales: hashes).isEmpty)
        hashes["asamblea.json"] = String(repeating: "ab", count: 32)
        XCTAssertEqual(manifiesto.pendientes(hashesLocales: hashes).map(\.path), ["asamblea.json"])
    }

    func testFeedDeEjemplo() throws {
        let (asamblea, hallazgos, votaciones) = try conjunto()
        XCTAssertTrue(asamblea.ejemplo)
        XCTAssertTrue(asamblea.aviso.localizedCaseInsensitiveContains("ejemplo"))
        XCTAssertEqual(asamblea.asambleistas.count, 2)
        XCTAssertEqual(NombresPublicos.iniciales("Asambleísta Ejemplo 1"), "AE")
        for persona in asamblea.asambleistas {
            XCTAssertTrue(persona.nombre.localizedCaseInsensitiveContains("ejemplo"))
            XCTAssertNil(persona.foto)
            XCTAssertNotNil(persona.asistencia)
        }
        XCTAssertEqual(Set(hallazgos.hallazgos.map(\.sello)), [.abierto, .hipotesis])
        XCTAssertEqual(votaciones.count, 2)
        let sentidos = Set(votaciones.flatMap(\.votos).map(\.voto))
        XCTAssertEqual(sentidos, [.afavor, .enContra, .abstencion, .ausente])
        let primera = try XCTUnwrap(asamblea.persona(id: "ejemplo-1"))
        XCTAssertEqual(primera.provincia, "Provincia Ejemplo")
        XCTAssertEqual(primera.partido, "Partido Ejemplo")
        XCTAssertEqual(primera.hallazgos, ["hal-ejemplo-1"])
        XCTAssertEqual(primera.asistencia?.presente, 8)
        XCTAssertEqual(primera.asistencia?.sesiones, 10)
    }

    func testRechazaCedulaCorreoYSelloEnElVoto() throws {
        let asamblea = try Data(contentsOf: feed().appendingPathComponent("v1/asamblea.json"))
        let texto = String(decoding: asamblea, as: UTF8.self)
        let conNumero = texto.replacingOccurrences(
            of: "Asambleísta Ejemplo 1",
            with: "Asambleísta Ejemplo 1 1234567890"
        )
        XCTAssertThrowsError(try conjunto(asamblea: Data(conNumero.utf8)))

        let correo = ["alguien", "ejemplo.invalid"].joined(separator: "@")
        let conCorreo = texto.replacingOccurrences(of: "Provincia Ejemplo", with: "Provincia \(correo)")
        XCTAssertThrowsError(try conjunto(asamblea: Data(conCorreo.utf8)))

        let votacion = try Data(contentsOf: feed().appendingPathComponent("v1/votaciones/vot-ejemplo-1.json"))
        let votacionTexto = String(decoding: votacion, as: UTF8.self)
        let conSello = votacionTexto.replacingOccurrences(
            of: "\"voto\": \"afavor\"",
            with: "\"voto\": \"afavor\", \"sello\": \"ABIERTO\""
        )
        XCTAssertThrowsError(try conjunto(votacion: Data(conSello.utf8), ruta: "votaciones/vot-ejemplo-1.json"))
    }

    private func conjunto(
        asamblea: Data? = nil,
        votacion: Data? = nil,
        ruta: String = "votaciones/vot-ejemplo-1.json"
    ) throws -> (IndiceAsamblea, IndiceHallazgos, [Votacion]) {
        let carpeta = feed().appendingPathComponent("v1")
        let datosAsamblea = try asamblea ?? Data(contentsOf: carpeta.appendingPathComponent("asamblea.json"))
        let datosHallazgos = try Data(contentsOf: carpeta.appendingPathComponent("hallazgos.json"))
        var sesiones: [(ruta: String, datos: Data)] = []
        for nombre in ["votaciones/vot-ejemplo-1.json", "votaciones/vot-ejemplo-2.json"] {
            if nombre == ruta, let votacion {
                sesiones.append((ruta, votacion))
            } else {
                sesiones.append((nombre, try Data(contentsOf: carpeta.appendingPathComponent(nombre))))
            }
        }
        return try ConjuntoAsamblea.validar(
            asamblea: datosAsamblea,
            hallazgos: datosHallazgos,
            votaciones: sesiones,
            origen: origen
        )
    }

    private func cargarManifiesto() throws -> ManifiestoFeed {
        let datos = try Data(contentsOf: feed().appendingPathComponent("v1/manifest.json"))
        return try JSONDecoder().decode(ManifiestoFeed.self, from: datos)
    }

    private func feed() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("data/app")
    }
}
