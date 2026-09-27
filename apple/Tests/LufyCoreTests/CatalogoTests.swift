import Foundation
import XCTest
import LufyCore

final class CatalogoTests: XCTestCase {
    func testCatalogoPublicadoEsValido() throws {
        let (catalogo, datos) = try cargar()
        XCTAssertNoThrow(try catalogo.validarIntegridad(json: datos))
        XCTAssertEqual(catalogo.schema, 1)
        XCTAssertEqual(catalogo.hilos.count, 1)
        XCTAssertEqual(catalogo.libro.paginas, 165)
        XCTAssertEqual(catalogo.libro.precioSugeridoUSD, 3)
        XCTAssertEqual(catalogo.libro.capitulos.count, 14)
        XCTAssertEqual(catalogo.libro.cantidadCapitulos, 14)
        XCTAssertTrue(catalogo.libro.capitulos.contains { $0.titulo.contains("feriado bancario") })
        XCTAssertTrue(catalogo.libro.capitulos.contains { $0.titulo.contains("muerte cruzada") })
        XCTAssertLessThan(catalogo.libro.muestra.joined(separator: " ").count, 800)
        XCTAssertEqual(Set(catalogo.historia.sellos.compactMap(\.sello)), Set(Sello.allCases))

        let hilo = try XCTUnwrap(catalogo.hilo(id: "campana-cne-2025"))
        XCTAssertEqual(Set(hilo.cifras.compactMap(\.sello)), [.confirmado, .abierto])
        XCTAssertTrue(hilo.lectura.contains { $0.ocr && $0.sello == nil })
        XCTAssertTrue(hilo.cifras.allSatisfy { $0.fuente.archivo == nil })
        XCTAssertTrue(catalogo.archivo.cifras.allSatisfy { $0.sello == nil && $0.fuente.archivo == nil })

        let texto = String(decoding: datos, as: UTF8.self)
        let marca = pegar("dimo", "linari")
        XCTAssertEqual(texto.components(separatedBy: marca).count - 1, 1)
        XCTAssertEqual(texto.components(separatedBy: "https://ko-fi.com").count - 1, 3)
        XCTAssertFalse(texto.contains("x.com"))
        XCTAssertFalse(texto.contains(marca + "18"))
        XCTAssertFalse(texto.contains("gob.ec"))
        XCTAssertFalse(texto.contains("archive.org"))
    }

    func testCifrasCoincidenConElCsv() throws {
        let (catalogo, datos) = try cargar()
        let texto = String(decoding: datos, as: UTF8.self)
        let csv = try String(contentsOf: raizRepo().appendingPathComponent("datos/cne-elecciones-generales-2025.csv"), encoding: .utf8)
        let filas = parsearCSV(csv)
        for fila in filas {
            for columna in ["ingresos_usd", "gasto_sin_iva_usd", "presupuesto_gastos_usd"] {
                let crudo = fila[columna] ?? ""
                guard !crudo.isEmpty else { continue }
                let esperado: String?
                if crudo.contains(".") {
                    esperado = Formato.dolarEs(crudo)
                } else if let entero = Int(crudo) {
                    esperado = Formato.dolarEsEntero(entero)
                } else {
                    esperado = nil
                }
                XCTAssertNotNil(esperado)
                XCTAssertTrue(texto.contains(esperado ?? ""), "Falta \(esperado ?? crudo) de \(fila["nombre"] ?? "")")
            }
        }

        let hilo = try XCTUnwrap(catalogo.hilo(id: "campana-cne-2025"))
        let tabla = try XCTUnwrap(tablaPresidencial(hilo))
        let presidenciales = filas.filter { $0["tabla"] == "presidencial_1a_vuelta" }
        XCTAssertEqual(presidenciales.count, 12)
        for fila in presidenciales {
            let nombre = try XCTUnwrap(fila["nombre"])
            let celda = try XCTUnwrap(tabla.filas.first { $0.celdas.first == nombre })
            XCTAssertEqual(celda.celdas[1], Formato.dolarEs(try XCTUnwrap(fila["ingresos_usd"])))
            XCTAssertEqual(celda.celdas[2], Formato.dolarEs(try XCTUnwrap(fila["gasto_sin_iva_usd"])))
            XCTAssertEqual(celda.celdas[3], Formato.dolarEs(try XCTUnwrap(fila["presupuesto_gastos_usd"])))
        }

        let ingresos = try XCTUnwrap(hilo.cifras.first { $0.id == "ingresos-1a" })
        let gasto = try XCTUnwrap(hilo.cifras.first { $0.id == "gasto-1a" })
        XCTAssertEqual(ingresos.numero ?? -1, 596455.65, accuracy: 0.001)
        XCTAssertEqual(gasto.numero ?? -1, 534609.69, accuracy: 0.001)
        XCTAssertEqual(ingresos.valor, "$596.455,65")
        XCTAssertEqual(gasto.valor, "$534.609,69")

        guard case .grafico(let dignidad) = hilo.bloques.first(where: { bloque in
            if case .grafico(let grafico) = bloque { return grafico.titulo.contains("dignidad") }
            return false
        }) else {
            return XCTFail("Sin gráfico de dignidades")
        }
        let pisos = filas.filter { $0["tabla"] == "dignidad_piso_1a_vuelta" && $0["nombre"] != "Suma del subconjunto legible" }
        XCTAssertEqual(pisos.count, dignidad.grupos.count)
        for fila in pisos {
            let nombre = try XCTUnwrap(fila["nombre"])
            let grupo = try XCTUnwrap(dignidad.grupos.first { $0.nombre.contains(nombre) })
            XCTAssertEqual(grupo.barras[0].valor, Double(fila["ingresos_usd"] ?? "") ?? -1, accuracy: 0.001)
        }
    }

    func testBarrasYConteos() throws {
        let (catalogo, _) = try cargar()
        let conteos = [
            ("documentos", 15089),
            ("fragmentos", 2096541),
            ("contratacion", 2761777),
            ("estados", 1660911),
            ("accionistas", 1303272),
            ("sanciones", 67154),
        ]
        for (id, numero) in conteos {
            let cifra = try XCTUnwrap(catalogo.archivo.cifras.first { $0.id == id })
            XCTAssertEqual(cifra.numero ?? -1, Double(numero), accuracy: 0.001)
            XCTAssertEqual(cifra.valor, Formato.enteroEs(numero))
            XCTAssertFalse(cifra.fuente.linea.isEmpty)
        }
        let maximo = try XCTUnwrap(catalogo.archivo.grafico.grupos.flatMap(\.barras).map(\.valor).max())
        XCTAssertEqual(maximo, 2_761_777, accuracy: 0.001)
        let primera = try XCTUnwrap(catalogo.archivo.grafico.grupos.first)
        XCTAssertEqual(catalogo.archivo.grafico.fraccion(grupo: primera, barra: primera.barras[0]), 1, accuracy: 0.0001)

        let hilo = try XCTUnwrap(catalogo.hilo(id: "campana-cne-2025"))
        guard case .grafico(let ingresos) = hilo.bloques.first(where: { bloque in
            if case .grafico(let grafico) = bloque { return grafico.titulo.hasPrefix("Ingresos declarados, Presidente") }
            return false
        }) else {
            return XCTFail("Sin gráfico de ingresos")
        }
        XCTAssertEqual(ingresos.fraccion(grupo: ingresos.grupos[0], barra: ingresos.grupos[0].barras[0]), 1, accuracy: 0.0001)
        let adn = ingresos.fraccion(grupo: ingresos.grupos[1], barra: ingresos.grupos[1].barras[0])
        XCTAssertEqual(adn, 224500 / 244802.52, accuracy: 0.001)
    }

    func testRechazaEnlaceOficialYEsquema() throws {
        let (_, datos) = try cargar()
        var texto = String(decoding: datos, as: UTF8.self)
        XCTAssertEqual(texto.components(separatedBy: "\"schema\": 1").count - 1, 1)
        texto = texto.replacingOccurrences(of: "\"schema\": 1", with: "\"schema\": 2")
        let cambiado = try CatalogoDecodificador.catalogo(datos: Data(texto.utf8))
        XCTAssertThrowsError(try cambiado.validarIntegridad(json: Data(texto.utf8)))

        let original = String(decoding: datos, as: UTF8.self)
        let envenenado = original.replacingOccurrences(
            of: "No acusamos a nadie.",
            with: "Ver https://www.cne.gob.ec/reporte"
        )
        let malo = try CatalogoDecodificador.catalogo(datos: Data(envenenado.utf8))
        XCTAssertThrowsError(try malo.validarIntegridad(json: Data(envenenado.utf8)))
    }

    func testMetaPublicada() throws {
        let datos = try Data(contentsOf: raizRepo().appendingPathComponent("data/meta.json"))
        let meta = try CatalogoDecodificador.meta(datos: datos)
        XCTAssertEqual(meta.textoCifra, "\(Formato.dolarMeta(meta.raisedUSD)) de \(Formato.dolarMeta(meta.goalUSD))")
        XCTAssertEqual(meta.textoFecha, "Actualizado: \(meta.updated)")
        XCTAssertGreaterThanOrEqual(meta.fraccion, 0)
        XCTAssertLessThanOrEqual(meta.fraccion, 1)
    }

    func testManifiestoDePrivacidadYProyecto() throws {
        let raiz = raizRepo()
        let manifiesto = try String(contentsOf: raiz.appendingPathComponent("apple/App/PrivacyInfo.xcprivacy"), encoding: .utf8)
        XCTAssertTrue(manifiesto.contains("<key>NSPrivacyTracking</key>"))
        XCTAssertTrue(manifiesto.contains("<false/>"))
        XCTAssertTrue(manifiesto.contains("<key>NSPrivacyCollectedDataTypes</key>"))
        XCTAssertTrue(manifiesto.contains("<key>NSPrivacyAccessedAPITypes</key>"))
        XCTAssertFalse(manifiesto.contains("<key>NSPrivacyCollectedDataType</key>"))

        let marca = pegar("dimo", "linari")
        let proyecto = try String(contentsOf: raiz.appendingPathComponent("apple/project.yml"), encoding: .utf8)
        XCTAssertTrue(proyecto.contains("PRODUCT_BUNDLE_IDENTIFIER: $(LUFY_BUNDLE_IDENTIFIER)"))
        XCTAssertTrue(proyecto.contains("PRODUCT_NAME: Lufy"))
        XCTAssertTrue(proyecto.contains("Signing.xcconfig"))
        XCTAssertTrue(proyecto.contains("LufyCoreTests"))
        XCTAssertFalse(proyecto.contains("DEVELOPMENT_TEAM"))
        XCTAssertFalse(proyecto.contains(marca))

        let firma = try String(contentsOf: raiz.appendingPathComponent("apple/Signing.xcconfig"), encoding: .utf8)
        XCTAssertTrue(firma.contains("LUFY_DEVELOPMENT_TEAM = ABCDE12345"))
        XCTAssertTrue(firma.contains("LUFY_BUNDLE_ID_BASE = com.lufy.app"))
        XCTAssertTrue(firma.contains("#include? \"Signing.local.xcconfig\""))
        XCTAssertFalse(firma.contains(marca))

        let ignorados = try String(contentsOf: raiz.appendingPathComponent("apple/.gitignore"), encoding: .utf8)
        XCTAssertTrue(ignorados.contains("Signing.local.xcconfig"))
        XCTAssertFalse(ignorados.contains("Signing.local.xcconfig.example"))

        let paquete = try String(contentsOf: raiz.appendingPathComponent("apple/Package.swift"), encoding: .utf8)
        XCTAssertTrue(paquete.contains(".iOS(.v17)"))
        XCTAssertTrue(paquete.contains(".macOS(.v14)"))

        let config = try String(contentsOf: raiz.appendingPathComponent("apple/App/Configuracion.swift"), encoding: .utf8)
        XCTAssertTrue(config.contains("static let capaDePagoActiva = false"))

        let plist = try String(contentsOf: raiz.appendingPathComponent("apple/App/Info.plist"), encoding: .utf8)
        XCTAssertTrue(plist.contains("<string>Lufy</string>"))
        XCTAssertFalse(plist.contains(marca))
    }

    func testArchivosSinDatosPersonales() throws {
        let raiz = raizRepo()
        let permitidos = [
            raiz.appendingPathComponent("apple/README.md").path,
            raiz.appendingPathComponent("data/contenido.json").path,
        ]
        var revisados: [URL] = []
        if let enumerador = FileManager.default.enumerator(at: raiz.appendingPathComponent("apple"), includingPropertiesForKeys: nil) {
            while let url = enumerador.nextObject() as? URL {
                if url.path.contains("/.build/") || url.path.contains(".xcodeproj") { continue }
                if ["swift", "md", "yml", "plist", "xcprivacy"].contains(url.pathExtension) {
                    revisados.append(url)
                }
            }
        }
        revisados.append(raiz.appendingPathComponent("data/contenido.json"))
        let marca = pegar("dimo", "linari")
        let prohibidos = [
            marca + "18",
            pegar("testa", "ferro"),
            pegar("cul", "pable"),
            pegar("corrup", "to"),
            pegar("corrup", "ta"),
            pegar("guil", "ty"),
        ]
        for url in revisados {
            let texto = try String(contentsOf: url, encoding: .utf8)
            let plano = texto.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
            for palabra in prohibidos {
                XCTAssertFalse(plano.contains(palabra), "Redaccion en \(url.lastPathComponent)")
            }
            XCTAssertNil(texto.range(of: "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}", options: [.regularExpression, .caseInsensitive]))
            if !permitidos.contains(url.path) {
                XCTAssertFalse(texto.lowercased().contains(marca), "Nombre en \(url.lastPathComponent)")
            }
        }
        let readme = try String(contentsOf: raiz.appendingPathComponent("apple/README.md"), encoding: .utf8)
        let (catalogo, _) = try cargar()
        XCTAssertTrue(readme.contains(catalogo.origen))
    }

    private func pegar(_ partes: String...) -> String {
        partes.joined()
    }

    private func tablaPresidencial(_ hilo: Hilo) -> Tabla? {
        for bloque in hilo.bloques {
            if case .tabla(let tabla) = bloque, tabla.titulo.contains("proceso 132") {
                return tabla
            }
        }
        return nil
    }

    private func cargar() throws -> (Catalogo, Data) {
        let url = raizRepo().appendingPathComponent("data/contenido.json")
        let datos = try Data(contentsOf: url)
        let catalogo = try CatalogoDecodificador.catalogo(datos: datos)
        return (catalogo, datos)
    }

    private func raizRepo() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func parsearCSV(_ texto: String) -> [[String: String]] {
        let lineas = texto.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
        guard let cabeza = lineas.first else { return [] }
        let columnas = partirCSV(cabeza)
        return lineas.dropFirst().map { linea in
            let celdas = partirCSV(linea)
            var fila: [String: String] = [:]
            for (indice, nombre) in columnas.enumerated() where indice < celdas.count {
                fila[nombre] = celdas[indice]
            }
            return fila
        }
    }

    private func partirCSV(_ linea: String) -> [String] {
        var campos: [String] = []
        var actual = ""
        var comillas = false
        for caracter in linea {
            if caracter == "\"" {
                comillas.toggle()
                continue
            }
            if caracter == ",", !comillas {
                campos.append(actual)
                actual = ""
                continue
            }
            actual.append(caracter)
        }
        campos.append(actual)
        return campos
    }
}
