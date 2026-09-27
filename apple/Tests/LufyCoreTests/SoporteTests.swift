import Foundation
import XCTest
import LufyCore

final class SoporteTests: XCTestCase {
    func testFechas() {
        XCTAssertTrue(Fechas.isoValida("2026-09-26"))
        XCTAssertTrue(Fechas.isoValida("2024-02-29"))
        XCTAssertFalse(Fechas.isoValida("2026-02-29"))
        XCTAssertFalse(Fechas.isoValida("2026-13-01"))
        XCTAssertFalse(Fechas.isoValida("26-09-2026"))
        XCTAssertFalse(Fechas.isoValida("2026-9-6"))
    }

    func testDolarMetaComoLaWeb() {
        XCTAssertEqual(Formato.dolarMeta(4700), "$4,700")
        XCTAssertEqual(Formato.dolarMeta(0), "$0")
        XCTAssertEqual(Formato.dolarMeta(1.2), "$1.20")
        XCTAssertEqual(Formato.dolarMeta(-5), "-$5")
        XCTAssertEqual(Formato.dolarMeta(5494525.60), "$5,494,525.60")
    }

    func testDolarEs() {
        XCTAssertEqual(Formato.dolarEs("596455.65"), "$596.455,65")
        XCTAssertEqual(Formato.dolarEs("534609.69"), "$534.609,69")
        XCTAssertEqual(Formato.dolarEs("5494525.60"), "$5.494.525,60")
        XCTAssertEqual(Formato.dolarEs("0.00"), "$0,00")
        XCTAssertEqual(Formato.dolarEs("301.75"), "$301,75")
        XCTAssertEqual(Formato.dolarEs("99980.00"), "$99.980,00")
        XCTAssertEqual(Formato.dolarEs("1121944.70"), "$1.121.944,70")
        XCTAssertEqual(Formato.dolarEsEntero(364370), "$364.370")
        XCTAssertEqual(Formato.enteroEs(15089), "15.089")
        XCTAssertEqual(Formato.enteroEs(2761777), "2.761.777")
    }

    func testSellosExactos() throws {
        for sello in Sello.allCases {
            let datos = Data("\"\(sello.rawValue)\"".utf8)
            XCTAssertEqual(try JSONDecoder().decode(Sello.self, from: datos), sello)
        }
        XCTAssertThrowsError(try JSONDecoder().decode(Sello.self, from: Data("\"HIPOTESIS\"".utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(Sello.self, from: Data("\"OCR\"".utf8)))
        let ajeno = "\"" + ["CUL", "PABLE"].joined() + "\""
        XCTAssertThrowsError(try JSONDecoder().decode(Sello.self, from: Data(ajeno.utf8)))
    }

    func testResolucion() {
        let bueno = Data("ok".utf8)
        let malo = Data("no".utf8)
        let acepta: (Data) -> Bool = { $0 == bueno }
        XCTAssertEqual(ResolucionContenido.elegir(red: bueno, cache: malo, paquete: malo, acepta: acepta)?.origen, .red)
        XCTAssertEqual(ResolucionContenido.elegir(red: malo, cache: bueno, paquete: malo, acepta: acepta)?.origen, .cache)
        XCTAssertEqual(ResolucionContenido.elegir(red: nil, cache: nil, paquete: bueno, acepta: acepta)?.origen, .paquete)
        XCTAssertEqual(ResolucionContenido.elegir(red: Data(), cache: Data(), paquete: bueno, acepta: acepta)?.origen, .paquete)
        XCTAssertNil(ResolucionContenido.elegir(red: malo, cache: nil, paquete: malo, acepta: acepta))
    }

    func testPoliticaNoSaleDelSitio() throws {
        let origen = "https://archivo.example/lufy-web/"
        let raiz = try XCTUnwrap(URL(string: origen))
        let copia = try XCTUnwrap(PoliticaEnlaces.urlLufy(origen: origen, ruta: "archivo/prueba.pdf"))
        XCTAssertEqual(copia.absoluteString, "https://archivo.example/lufy-web/archivo/prueba.pdf")
        XCTAssertTrue(PoliticaEnlaces.puedeAbrir(copia, origen: raiz, mostrarKoFi: false))

        XCTAssertNil(PoliticaEnlaces.urlLufy(origen: origen, ruta: "https://www.cne.gob.ec/reporte.pdf"))
        XCTAssertNil(PoliticaEnlaces.urlLufy(origen: origen, ruta: "https://web.archive.org/web/x"))
        XCTAssertNil(PoliticaEnlaces.urlLufy(origen: origen, ruta: "http://archivo.example/lufy-web/a.pdf"))
        XCTAssertNil(PoliticaEnlaces.urlLufy(origen: origen, ruta: "../secreto.pdf"))
        XCTAssertNil(PoliticaEnlaces.urlLufy(origen: origen, ruta: "https://archivo.example/otro/a.pdf"))

        let kofi = try XCTUnwrap(PoliticaEnlaces.urlKoFi("https://ko-fi.com/guardianlufy"))
        XCTAssertFalse(PoliticaEnlaces.puedeAbrir(kofi, origen: raiz, mostrarKoFi: false))
        XCTAssertTrue(PoliticaEnlaces.puedeAbrir(kofi, origen: raiz, mostrarKoFi: true))
        XCTAssertNil(PoliticaEnlaces.urlKoFi("https://ko-fi.com.evil.example/guardianlufy"))
        XCTAssertNil(PoliticaEnlaces.urlKoFi("https://evil.example/ko-fi.com"))

        let gobierno = try XCTUnwrap(URL(string: "https://www.contraloria.gob.ec/informe"))
        XCTAssertFalse(PoliticaEnlaces.puedeAbrir(gobierno, origen: raiz, mostrarKoFi: true))
    }

    func testCopiaArchivada() throws {
        let origen = "https://archivo.example/lufy-web/"
        let huella = String(repeating: "ab", count: 32)
        let json = """
        {"institucion":"Lufy","documento":"Prueba","fecha":"2026-09-26","linea":"Fuente: Lufy, prueba, 26 de septiembre de 2026.","archivo":{"ruta":"archivo/prueba.pdf","sha256":"\(huella)","archivado":"2026-09-26"}}
        """
        let fuente = try JSONDecoder().decode(Fuente.self, from: Data(json.utf8))
        XCTAssertNoThrow(try fuente.validar(origen: origen))
        XCTAssertEqual(fuente.archivo?.sha256.count, 64)

        let mala = json.replacingOccurrences(of: "archivo/prueba.pdf", with: "https://www.cne.gob.ec/a.pdf")
        let fuenteMala = try JSONDecoder().decode(Fuente.self, from: Data(mala.utf8))
        XCTAssertThrowsError(try fuenteMala.validar(origen: origen))
    }

    func testMetaRechazaCifrasRotas() {
        XCTAssertThrowsError(try CatalogoDecodificador.meta(datos: Data(#"{"goal_usd":0,"raised_usd":1,"updated":"2026-09-26"}"#.utf8)))
        XCTAssertThrowsError(try CatalogoDecodificador.meta(datos: Data(#"{"goal_usd":10,"raised_usd":-1,"updated":"2026-09-26"}"#.utf8)))
        XCTAssertThrowsError(try CatalogoDecodificador.meta(datos: Data(#"{"goal_usd":10,"raised_usd":0,"updated":"2026-02-29"}"#.utf8)))
    }
}
