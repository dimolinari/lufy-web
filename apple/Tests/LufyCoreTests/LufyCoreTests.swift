import Foundation
import Testing
@testable import LufyCore

struct IndiceTests {
    @Test func abreElIndiceEmpaquetado() throws {
        let datos = try ContenidoEmpaquetado.datosContenido()
        let contenido = try DecodificadorContenido.decodificar(datos)
        #expect(contenido.version == 1)
        #expect(contenido.hilos.count == 1)
        #expect(contenido.hilos[0].id == "campana-2025")
        #expect(contenido.libro.textoCompletoIncluido == false)
        #expect(contenido.libro.autor == "Lufy")
        #expect(contenido.libro.capitulos.count == 14)
        #expect(contenido.libro.sugeridoUSD == 3)
        #expect(contenido.libro.muestra.paginas == 18)
        #expect(contenido.libro.capitulos.first { $0.enMuestra }?.numero == 8)
    }

    @Test func elIndiceDelSitioYElEmpaquetadoSonElMismo() throws {
        let empaquetado = try ContenidoEmpaquetado.datosContenido()
        let sitio = try Data(contentsOf: urlDelSitio("data/contenido.json"))
        #expect(empaquetado == sitio)
        let metaEmpaquetada = try ContenidoEmpaquetado.datosMeta()
        let metaSitio = try Data(contentsOf: urlDelSitio("data/meta.json"))
        #expect(metaEmpaquetada == metaSitio)
    }

    @Test func noHayNombreDeCuentaNiCorreoEnElIndice() throws {
        let texto = String(decoding: try ContenidoEmpaquetado.datosContenido(), as: UTF8.self)
        #expect(!texto.contains("dimolinari"))
        #expect(texto.range(of: #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#, options: [.regularExpression, .caseInsensitive]) == nil)
    }

    @Test func sellosSoloLosCuatro() throws {
        let contenido = try decodificarEmpaquetado()
        let crudo = String(decoding: try ContenidoEmpaquetado.datosContenido(), as: UTF8.self)
        #expect(crudo.contains("CONFIRMADO"))
        #expect(crudo.contains("ABIERTO"))
        #expect(crudo.contains("INDICIO"))
        #expect(crudo.contains("HIPÓTESIS"))
        #expect(!crudo.contains("CULPABLE"))
        #expect(!crudo.contains("TESTAFERRO"))
        let sellos = sellos(de: contenido)
        #expect(sellos.contains(.confirmado))
        #expect(sellos.contains(.abierto))
        #expect(sellos.contains(.indicio))
        #expect(sellos.contains(.hipotesis))
        #expect(Set(sellos).isSubset(of: Set(Sello.allCases)))
    }

    @Test func sumaDeIngresosYGastosDeLaPrimeraVuelta() throws {
        let contenido = try decodificarEmpaquetado()
        let tabla = try #require(tablas(de: contenido).first { $0.titulo.contains("proceso 132") })
        #expect(tabla.filas.count == 12)
        let ingresos = try sumar(tabla, columna: 1)
        let gastos = try sumar(tabla, columna: 2)
        #expect(ingresos == Decimal(string: "596455.65"))
        #expect(gastos == Decimal(string: "534609.69"))
        let ocr = tabla.filas.filter { $0.ocr == true }.compactMap(\.celdas.first)
        #expect(ocr == ["ADN", "PID"])
    }

    @Test func elMayorGastoEsElPorcentajePublicado() throws {
        let gasto = try #require(Montos.ecuador("$216.608,60"))
        let limite = try #require(Montos.ecuador("$5.494.525,60"))
        let porcentaje = (gasto / limite) * 100
        var redondeado = Decimal()
        var copia = porcentaje
        NSDecimalRound(&redondeado, &copia, 2, .plain)
        #expect(redondeado == Decimal(string: "3.94"))
    }

    @Test func rutasQuedanEnLufy() throws {
        let contenido = try decodificarEmpaquetado()
        for hilo in contenido.hilos {
            let url = try #require(PoliticaEnlaces.urlLufy(ruta: hilo.ruta))
            #expect(PoliticaEnlaces.esLufy(url))
            if let adjunto = hilo.adjunto {
                #expect(PoliticaEnlaces.urlLufy(ruta: adjunto.ruta) != nil)
            }
            #expect(hilo.fuente.archivo == nil)
        }
        #expect(PoliticaEnlaces.urlLufy(ruta: contenido.libro.ruta) != nil)
        #expect(contenido.archivo.cifras.allSatisfy { $0.fuente.archivo == nil })
    }

    @Test func rechazaSitioOficialPalabraProhibidaYLibroCompleto() throws {
        let base = String(decoding: try ContenidoEmpaquetado.datosContenido(), as: UTF8.self)
        let conGobierno = base.replacingOccurrences(
            of: "No acusamos a nadie.",
            with: "No acusamos a nadie. Ver https://www.cne.gob.ec/transparencia"
        )
        #expect(throws: ErrorContenido.self) {
            try DecodificadorContenido.decodificar(Data(conGobierno.utf8))
        }
        let conPalabra = base.replacingOccurrences(
            of: "No acusamos a nadie.",
            with: "No acusamos a nadie. Lo llama testaferro."
        )
        #expect(throws: ErrorContenido.self) {
            try DecodificadorContenido.decodificar(Data(conPalabra.utf8))
        }
        let conLibro = base.replacingOccurrences(
            of: "\"textoCompletoIncluido\": false",
            with: "\"textoCompletoIncluido\": true"
        )
        #expect(throws: ErrorContenido.self) {
            try DecodificadorContenido.decodificar(Data(conLibro.utf8))
        }
        let conCedula = base.replacingOccurrences(
            of: "No acusamos a nadie.",
            with: "No acusamos a nadie. 1234567890"
        )
        #expect(throws: ErrorContenido.self) {
            try DecodificadorContenido.decodificar(Data(conCedula.utf8))
        }
    }

    @Test func idaYVueltaDelIndice() throws {
        let contenido = try decodificarEmpaquetado()
        let datos = try JSONEncoder().encode(contenido)
        let otra = try DecodificadorContenido.decodificar(datos)
        #expect(otra.hilos[0].titulo == contenido.hilos[0].titulo)
        #expect(otra.libro.capitulos.map(\.ancla) == contenido.libro.capitulos.map(\.ancla))
        #expect(otra.enlaces.apoyo == contenido.enlaces.apoyo)
    }
}

struct PoliticaTests {
    @Test func rechazaGobiernoYAceptaLufy() {
        let cne = URL(string: "https://www.cne.gob.ec/transparencia")!
        #expect(!PoliticaEnlaces.urlPermitida(cne))
        #expect(PoliticaEnlaces.urlLufy(ruta: "datos/financiamiento-campana-cne-2025.html") != nil)
        #expect(PoliticaEnlaces.urlLufy(ruta: "../secreto.pdf") == nil)
        #expect(PoliticaEnlaces.urlLufy(ruta: "https://dimolinari.github.io/lufy-web/x.pdf") == nil)
        let otroHost = URL(string: "https://evil.example/lufy-web/archivo.pdf")!
        #expect(!PoliticaEnlaces.esLufy(otroHost))
        let falso = URL(string: "https://dimolinari.github.io.evil.com/lufy-web/a.pdf")!
        #expect(!PoliticaEnlaces.esLufy(falso))
        let absoluto = URL(string: "https://dimolinari.github.io/lufy-web/archivo/acta.pdf")!
        #expect(PoliticaEnlaces.esLufy(absoluto))
    }

    @Test func koFiSoloConElInterruptor() {
        let apoyo = URL(string: "https://ko-fi.com/guardianlufy")!
        let truco = URL(string: "https://ko-fi.com.evil.com/guardianlufy")!
        let claro = URL(string: "http://ko-fi.com/guardianlufy")!
        #expect(Ajustes.enlaceKoFi(apoyo, muestra: true) == apoyo)
        #expect(Ajustes.enlaceKoFi(apoyo, muestra: false) == nil)
        #expect(PoliticaEnlaces.urlKoFi(truco) == nil)
        #expect(PoliticaEnlaces.urlKoFi(claro) == nil)
        #expect(Ajustes.muestraEnlacesKoFi)
    }

    @Test func laHuellaEsHexDe64() {
        #expect(HuellaSHA256.esValida(String(repeating: "ab", count: 32)))
        #expect(!HuellaSHA256.esValida("abc"))
        #expect(!HuellaSHA256.esValida(String(repeating: "zz", count: 32)))
    }

    @Test func laHuellaConocidaYElVeredicto() {
        let vacio = Data()
        #expect(HuellaSHA256.de(vacio) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        let abc = Data("abc".utf8)
        #expect(HuellaSHA256.de(abc) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let esperada = HuellaSHA256.de(abc)
        #expect(HuellaSHA256.veredicto(datos: abc, esperada: esperada) == .coincide)
        #expect(HuellaSHA256.veredicto(datos: abc, esperada: esperada.uppercased()) == .coincide)
        #expect(HuellaSHA256.veredicto(datos: Data("abd".utf8), esperada: esperada) == .distinta)
        #expect(HuellaSHA256.veredicto(datos: abc, esperada: "no-es-huella") == .invalida)
    }

    @Test func elAdjuntoEmpaquetadoCoincideConElSitio() throws {
        let sitio = try Data(contentsOf: urlDelSitio("datos/cne-elecciones-generales-2025.csv"))
        let empaquetado = try #require(ContenidoEmpaquetado.datosAdjunto(ruta: "datos/cne-elecciones-generales-2025.csv"))
        #expect(empaquetado == sitio)
        #expect(ContenidoEmpaquetado.datosAdjunto(ruta: "https://ejemplo.gob.ec/acta.csv") == nil)
        #expect(ContenidoEmpaquetado.datosAdjunto(ruta: "../secreto.csv") == nil)
    }
}

struct MetaTests {
    @Test func metaPublicaEnCero() throws {
        let meta = try MetaRecaudacion.decodificar(ContenidoEmpaquetado.datosMeta())
        #expect(meta.texto == "$0 de $4,700")
        #expect(meta.fraccion == 0)
        #expect(meta.actualizado == "2026-09-26")
    }

    @Test func formatosYTopes() throws {
        #expect(FormatoDinero.dolaresEEUU(0) == "$0")
        #expect(FormatoDinero.dolaresEEUU(4700) == "$4,700")
        #expect(FormatoDinero.dolaresEEUU(Decimal(string: "12.5")!) == "$12.50")
        #expect(FormatoDinero.dolaresEEUU(1234567) == "$1,234,567")
        let mitad = try MetaRecaudacion.interpretar(meta: 4700, recaudado: 2350, actualizado: "2026-09-26")
        #expect(mitad.texto == "$2,350 de $4,700")
        #expect(mitad.fraccion == 0.5)
        let pasa = try MetaRecaudacion.interpretar(meta: 4700, recaudado: 9400, actualizado: "2026-09-26")
        #expect(pasa.texto == "$9,400 de $4,700")
        #expect(pasa.fraccion == 1)
        #expect(throws: ErrorContenido.self) {
            try MetaRecaudacion.interpretar(meta: 0, recaudado: 1, actualizado: "2026-09-26")
        }
        #expect(throws: ErrorContenido.self) {
            try MetaRecaudacion.interpretar(meta: 10, recaudado: -1, actualizado: "2026-09-26")
        }
        #expect(throws: ErrorContenido.self) {
            try MetaRecaudacion.interpretar(meta: 10, recaudado: 0, actualizado: "2026-02-31")
        }
    }

    @Test func montosEcuatorianos() {
        #expect(Montos.ecuador("$596.455,65") == Decimal(string: "596455.65"))
        #expect(Montos.ecuador("$0,00") == 0)
        #expect(Montos.ecuador("Sin total") == nil)
    }
}

struct TextoTests {
    @Test func marcasSinEnlaces() {
        let partes = TextoMarcado.fragmentos("En la 1.ª vuelta, **$596.455,65** de ingresos y un _piso_.")
        #expect(partes.map(\.estilo) == [.normal, .fuerte, .normal, .enfasis, .normal])
        #expect(partes.map(\.texto).joined() == "En la 1.ª vuelta, $596.455,65 de ingresos y un piso.")
    }
}

struct CargadorTests {
    @Test func laRedGanaYSeGuarda() async throws {
        let empaquetado = try ContenidoEmpaquetado.datosContenido()
        let meta = try ContenidoEmpaquetado.datosMeta()
        let almacen = AlmacenEnMemoria()
        let cargador = CargadorContenido(
            red: RedFija { url in
                url.path.hasSuffix("meta.json") ? meta : empaquetado
            },
            almacen: almacen,
            empaquetadoContenido: empaquetado,
            empaquetadoMeta: meta,
            urlContenido: try #require(OrigenPublico.url(OrigenPublico.rutaContenido)),
            urlMeta: try #require(OrigenPublico.url(OrigenPublico.rutaMeta))
        )
        let carga = await cargador.cargar()
        guard case .listo(_, .red) = carga.contenido else {
            Issue.record("Se esperaba el índice desde la red")
            return
        }
        guard case .valor(_, .red) = carga.meta else {
            Issue.record("Se esperaba la meta desde la red")
            return
        }
        #expect(await almacen.leer(ClavesCache.contenido) == empaquetado)
    }

    @Test func sinRedUsaCacheYLuegoElEmpaquetado() async throws {
        let empaquetado = try ContenidoEmpaquetado.datosContenido()
        let meta = try ContenidoEmpaquetado.datosMeta()
        let urlContenido = try #require(OrigenPublico.url(OrigenPublico.rutaContenido))
        let urlMeta = try #require(OrigenPublico.url(OrigenPublico.rutaMeta))
        let almacen = AlmacenEnMemoria()
        await almacen.escribir(ClavesCache.contenido, datos: empaquetado)
        let cargador = CargadorContenido(
            red: RedFija { _ in throw ErrorContenido.red },
            almacen: almacen,
            empaquetadoContenido: empaquetado,
            empaquetadoMeta: meta,
            urlContenido: urlContenido,
            urlMeta: urlMeta
        )
        let conCache = await cargador.cargar()
        guard case .listo(_, .cache) = conCache.contenido else {
            Issue.record("Se esperaba la caché")
            return
        }
        guard case .valor(_, .empaquetado) = conCache.meta else {
            Issue.record("La meta debía caer al empaquetado")
            return
        }

        let vacio = AlmacenEnMemoria()
        let sinNada = CargadorContenido(
            red: RedFija { _ in throw ErrorContenido.red },
            almacen: vacio,
            empaquetadoContenido: empaquetado,
            empaquetadoMeta: meta,
            urlContenido: urlContenido,
            urlMeta: urlMeta
        )
        let primera = await sinNada.cargar()
        guard case .listo(_, .empaquetado) = primera.contenido else {
            Issue.record("Se esperaba la copia empaquetada")
            return
        }
    }

    @Test func noGuardaUnaRespuestaInvalida() async throws {
        let empaquetado = try ContenidoEmpaquetado.datosContenido()
        let meta = try ContenidoEmpaquetado.datosMeta()
        let almacen = AlmacenEnMemoria()
        await almacen.escribir(ClavesCache.contenido, datos: empaquetado)
        let cargador = CargadorContenido(
            red: RedFija { url in
                if url.path.hasSuffix("meta.json") { return meta }
                return Data("no es json".utf8)
            },
            almacen: almacen,
            empaquetadoContenido: empaquetado,
            empaquetadoMeta: meta,
            urlContenido: try #require(OrigenPublico.url(OrigenPublico.rutaContenido)),
            urlMeta: try #require(OrigenPublico.url(OrigenPublico.rutaMeta))
        )
        let carga = await cargador.cargar()
        guard case .listo(_, .cache) = carga.contenido else {
            Issue.record("Una respuesta rota no debe reemplazar la caché")
            return
        }
        #expect(await almacen.leer(ClavesCache.contenido) == empaquetado)
    }
}

private struct RedFija: LectorRed {
    var cuerpo: @Sendable (URL) async throws -> Data
    func leer(_ url: URL) async throws -> Data { try await cuerpo(url) }
}

private func urlDelSitio(_ ruta: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(ruta)
}

private func decodificarEmpaquetado() throws -> ContenidoLufy {
    try DecodificadorContenido.decodificar(ContenidoEmpaquetado.datosContenido())
}

private func tablas(de contenido: ContenidoLufy) -> [Tabla] {
    contenido.hilos.flatMap { hilo in
        hilo.secciones.flatMap { seccion in
            seccion.bloques.compactMap { bloque in
                if case .tabla(let tabla) = bloque { return tabla }
                return nil
            }
        }
    }
}

private func sumar(_ tabla: Tabla, columna: Int) throws -> Decimal {
    try tabla.filas.reduce(Decimal(0)) { parcial, fila in
        let texto = try #require(fila.celdas.dropFirst(columna).first)
        return parcial + (try #require(Montos.ecuador(texto)))
    }
}

private func sellos(de contenido: ContenidoLufy) -> [Sello] {
    var lista: [Sello] = []
    func tomar(_ bloque: Bloque) {
        switch bloque {
        case .cifras(let cifras):
            lista.append(contentsOf: cifras.compactMap(\.sello))
        case .leyenda(let items):
            lista.append(contentsOf: items.compactMap(\.sello))
        default:
            break
        }
    }
    for hilo in contenido.hilos {
        lista.append(contentsOf: hilo.destacados.compactMap(\.sello))
        hilo.secciones.flatMap(\.bloques).forEach(tomar)
    }
    for pagina in [contenido.inicio, contenido.datos, contenido.apoyo, contenido.historia, contenido.privacidad] {
        pagina.secciones.flatMap(\.bloques).forEach(tomar)
    }
    return lista
}
