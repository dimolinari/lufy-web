import Foundation
import XCTest
import LufyCore

final class TarjetaAccesoTests: XCTestCase {
    private let origen = "https://archivo.example/lufy-web/"
    private let ruta = "datos/index.html"

    func testMedidasDeHistoria() {
        XCTAssertEqual(TarjetaCompartible.pixelesAncho, 1080)
        XCTAssertEqual(TarjetaCompartible.pixelesAlto, 1920)
        XCTAssertEqual(TarjetaCompartible.pixelesAncho * 16, TarjetaCompartible.pixelesAlto * 9)
        XCTAssertEqual(AccesoTemprano.diasPorDefecto, 7)
    }

    func testTarjetaDeHallazgoConservaSelloYFuente() throws {
        let hallazgo = try JSONDecoder().decode(HallazgoPublico.self, from: Data(hallazgoJSON.utf8))
        let tarjeta = try TarjetasLufy.hallazgo(hallazgo, origen: origen, ruta: ruta)
        XCTAssertEqual(tarjeta.sello, .abierto)
        XCTAssertEqual(tarjeta.sello?.rawValue, "ABIERTO")
        XCTAssertEqual(tarjeta.titulo, hallazgo.titulo)
        XCTAssertEqual(tarjeta.texto, hallazgo.texto)
        XCTAssertEqual(tarjeta.lineaFuente, hallazgo.fuente.linea)
        XCTAssertEqual(tarjeta.url.absoluteString, "https://archivo.example/lufy-web/datos/index.html")
    }

    func testTarjetaDeVotoNoInventaSello() throws {
        let votacion = try JSONDecoder().decode(Votacion.self, from: Data(votacionJSON.utf8))
        let tarjeta = try TarjetasLufy.voto(
            nombre: "Asambleísta Ejemplo 1",
            votacion: votacion,
            sentido: .afavor,
            origen: origen,
            ruta: ruta
        )
        XCTAssertNil(tarjeta.sello)
        XCTAssertEqual(tarjeta.titulo, votacion.titulo)
        XCTAssertEqual(tarjeta.texto, "Asambleísta Ejemplo 1: A favor")
        XCTAssertEqual(tarjeta.lineaFuente, votacion.fuente.linea)
        for sello in Sello.allCases {
            XCTAssertFalse(tarjeta.titulo.contains(sello.rawValue))
            XCTAssertFalse(tarjeta.texto.contains(sello.rawValue))
            XCTAssertFalse(tarjeta.lineaFuente.contains(sello.rawValue))
        }
    }

    func testTarjetaDeGraficoNoLlevaSello() throws {
        let grafico = try JSONDecoder().decode(Grafico.self, from: Data(graficoJSON.utf8))
        let tarjeta = try TarjetasLufy.grafico(grafico, origen: origen, ruta: ruta)
        XCTAssertNil(tarjeta.sello)
        XCTAssertEqual(tarjeta.titulo, "Cifras de ejemplo")
        XCTAssertEqual(tarjeta.lineaFuente, "Fuente: nota de ejemplo, 1 de enero de 2026.")
        XCTAssertTrue(tarjeta.texto.contains("Grupo"))
        XCTAssertTrue(tarjeta.texto.contains("1"))
    }

    func testTarjetaRechazaRedaccionYEnlaceAjeno() {
        let acusacion = ["cul", "pable"].joined()
        XCTAssertThrowsError(
            try TarjetasLufy.armar(
                titulo: "Titulo de ejemplo",
                texto: acusacion,
                sello: nil,
                lineaFuente: "Fuente: nota de ejemplo, 1 de enero de 2026.",
                origen: origen,
                ruta: ruta
            )
        )
        XCTAssertThrowsError(
            try TarjetasLufy.armar(
                titulo: "Titulo de ejemplo",
                texto: "Texto de ejemplo.",
                sello: nil,
                lineaFuente: "Fuente: nota de ejemplo, 1 de enero de 2026.",
                origen: origen,
                ruta: "https://archivo.example.gob.ec/a"
            )
        )
    }

    func testAccesoTemprano() throws {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let ahora = try XCTUnwrap(
            calendario.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 8, minute: 0, second: 0))
        )
        XCTAssertTrue(AccesoTemprano.visible(hasta: "2027-02-01", ahora: ahora, capaDePagoActiva: false, suscrito: false))
        XCTAssertTrue(AccesoTemprano.visible(hasta: nil, ahora: ahora, capaDePagoActiva: true, suscrito: false))
        XCTAssertTrue(AccesoTemprano.visible(hasta: "", ahora: ahora, capaDePagoActiva: true, suscrito: false))
        XCTAssertTrue(AccesoTemprano.visible(hasta: "2027-02-01", ahora: ahora, capaDePagoActiva: true, suscrito: true))
        XCTAssertFalse(AccesoTemprano.visible(hasta: "2027-02-01", ahora: ahora, capaDePagoActiva: true, suscrito: false))
        XCTAssertTrue(AccesoTemprano.visible(hasta: "2027-01-01", ahora: ahora, capaDePagoActiva: true, suscrito: false))
        XCTAssertTrue(AccesoTemprano.visible(hasta: "2027-01-15", ahora: ahora, capaDePagoActiva: true, suscrito: false))
        XCTAssertTrue(AccesoTemprano.visible(hasta: "2027-01-15T08:00:00Z", ahora: ahora, capaDePagoActiva: true, suscrito: false))
        XCTAssertFalse(AccesoTemprano.visible(hasta: "2027-01-15T09:00:00Z", ahora: ahora, capaDePagoActiva: true, suscrito: false))
        XCTAssertFalse(AccesoTemprano.visible(hasta: "manana", ahora: ahora, capaDePagoActiva: true, suscrito: false))
        XCTAssertFalse(
            AccesoTemprano.dossierVisible(
                hasta: nil,
                ahora: ahora,
                capaDePagoActiva: false,
                suscrito: true,
                comprado: true
            )
        )
        XCTAssertTrue(
            AccesoTemprano.dossierVisible(
                hasta: "2027-02-01",
                ahora: ahora,
                capaDePagoActiva: true,
                suscrito: true,
                comprado: false
            )
        )
        XCTAssertTrue(
            AccesoTemprano.dossierVisible(
                hasta: "2027-02-01",
                ahora: ahora,
                capaDePagoActiva: true,
                suscrito: false,
                comprado: true
            )
        )
        XCTAssertFalse(
            AccesoTemprano.dossierVisible(
                hasta: "2027-02-01",
                ahora: ahora,
                capaDePagoActiva: true,
                suscrito: false,
                comprado: false
            )
        )
    }

    func testAvisosCopianElTituloPublicado() {
        let hallazgo = PiezaFeed(
            id: "hallazgo:hal-1",
            titulo: "Dato de ejemplo, todavía abierto",
            lineaFuente: "Fuente: nota de ejemplo, 1 de enero de 2026.",
            sello: .abierto,
            legisladores: ["ejemplo-1"],
            institucion: "Lufy",
            tema: "ejemplo"
        )
        let voto = PiezaFeed(
            id: "votacion:vot-1",
            titulo: "Votación de ejemplo",
            lineaFuente: "Fuente: acta de ejemplo, 1 de enero de 2026.",
            sello: nil,
            legisladores: ["ejemplo-1"],
            institucion: "Lufy",
            tema: ""
        )
        let seguir = [Seguimiento(clase: .legislador, clave: "ejemplo-1")]
        XCTAssertTrue(AvisosSeguimiento.novedades(anteriores: nil, piezas: [hallazgo, voto], seguimientos: seguir).isEmpty)
        let avisos = AvisosSeguimiento.novedades(anteriores: [], piezas: [hallazgo, voto], seguimientos: seguir)
        XCTAssertEqual(avisos.map(\.titulo), [hallazgo.titulo, voto.titulo])
        XCTAssertEqual(avisos.map(\.lineaFuente), [hallazgo.lineaFuente, voto.lineaFuente])
        XCTAssertEqual(avisos.map(\.sello), [.abierto, nil])
        XCTAssertTrue(
            AvisosSeguimiento.novedades(
                anteriores: [hallazgo.id, voto.id],
                piezas: [hallazgo, voto],
                seguimientos: seguir
            ).isEmpty
        )
        let otro = PiezaFeed(
            id: "hallazgo:hal-2",
            titulo: "Otro dato de ejemplo",
            lineaFuente: hallazgo.lineaFuente,
            sello: .hipotesis,
            legisladores: ["ejemplo-2"],
            institucion: "Otra",
            tema: "muestra"
        )
        XCTAssertTrue(
            AvisosSeguimiento.novedades(anteriores: [], piezas: [otro], seguimientos: seguir).isEmpty
        )
        let porInstitucion = AvisosSeguimiento.novedades(
            anteriores: [],
            piezas: [hallazgo],
            seguimientos: [Seguimiento(clase: .institucion, clave: "lufy")]
        )
        XCTAssertEqual(porInstitucion.map(\.titulo), [hallazgo.titulo])
        let porTema = AvisosSeguimiento.novedades(
            anteriores: [],
            piezas: [voto],
            seguimientos: [Seguimiento(clase: .tema, clave: "ejemplo")]
        )
        XCTAssertTrue(porTema.isEmpty)
    }

    private let hallazgoJSON = """
    {
      "id": "hal-ejemplo-1",
      "sello": "ABIERTO",
      "titulo": "Dato de ejemplo, todavía abierto",
      "texto": "Dato de ejemplo. No afirma un hecho.",
      "tema": "ejemplo",
      "asambleistas": ["ejemplo-1"],
      "early_access_until": null,
      "fuente": {
        "institucion": "Lufy",
        "documento": "Nota de ejemplo",
        "fecha": "2026-01-01",
        "linea": "Fuente: nota de ejemplo, 1 de enero de 2026.",
        "archivo": null
      }
    }
    """

    private let votacionJSON = """
    {
      "schema": 1,
      "id": "vot-ejemplo-1",
      "fecha": "2026-01-01",
      "titulo": "Votación de ejemplo",
      "sesion": "Sesión de ejemplo",
      "acta": "Acta de ejemplo",
      "fuente": {
        "institucion": "Lufy",
        "documento": "Acta de ejemplo",
        "fecha": "2026-01-01",
        "linea": "Fuente: acta de ejemplo, 1 de enero de 2026.",
        "archivo": null
      },
      "votos": []
    }
    """

    private let graficoJSON = """
    {
      "titulo": "Cifras de ejemplo",
      "nota": "Nota publicada.",
      "escala": "compartida",
      "leyenda": [],
      "grupos": [
        {
          "nombre": "Grupo",
          "ocr": false,
          "barras": [
            {"etiqueta": "A", "valor": 1, "texto": "1", "tono": "oro"}
          ]
        }
      ],
      "fuente": {
        "institucion": "Lufy",
        "documento": "Nota de ejemplo",
        "fecha": "2026-01-01",
        "linea": "Fuente: nota de ejemplo, 1 de enero de 2026.",
        "archivo": null
      }
    }
    """
}
