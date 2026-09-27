import Foundation

extension Catalogo {
    public static let schemaActual = 1
    public static let largoMaximoTexto = 2000

    public func validarIntegridad(json: Data, origenEsperado: String? = nil) throws {
        guard schema == Self.schemaActual else { throw ErrorLufy.schema(schema) }
        guard let raiz = PoliticaEnlaces.normalizarOrigen(origen) else {
            throw ErrorLufy.enlaceProhibido(origen)
        }
        if let origenEsperado {
            guard PoliticaEnlaces.normalizarOrigen(origenEsperado) == raiz else {
                throw ErrorLufy.enlaceProhibido(origen)
            }
        }
        guard Fechas.isoValida(actualizado) else { throw ErrorLufy.fechaInvalida(actualizado) }
        guard Fechas.isoValida(privacidad.actualizado) else {
            throw ErrorLufy.fechaInvalida(privacidad.actualizado)
        }
        guard !notaSinCopia.isEmpty else { throw ErrorLufy.contenidoIncompleto("notaSinCopia") }

        let textos = try Self.cadenas(en: json)
        try PoliticaEnlaces.auditarTextos(textos, origen: origen, enlacesKoFi: enlaces.todos)
        let marca = ["dimo", "linari"].joined()
        for texto in textos where texto.lowercased().contains(marca) {
            guard PoliticaEnlaces.urlLufy(origen: origen, ruta: texto) != nil else {
                throw ErrorLufy.textoProhibido("nombre")
            }
        }
        for texto in textos where texto.count > Self.largoMaximoTexto {
            throw ErrorLufy.contenidoIncompleto("texto largo")
        }

        for enlace in enlaces.todos {
            guard PoliticaEnlaces.urlKoFi(enlace) != nil else {
                throw ErrorLufy.enlaceProhibido(enlace)
            }
        }
        guard Set(enlaces.todos).count == enlaces.todos.count else {
            throw ErrorLufy.contenidoIncompleto("enlaces")
        }

        try validarRuta(datos.rutaWeb, origen: raiz)
        try validarRuta(libro.rutaWeb, origen: raiz)
        try validarRuta(apoyo.rutaWeb, origen: raiz)
        try validarRuta(historia.rutaWeb, origen: raiz)
        try validarRuta(privacidad.rutaWeb, origen: raiz)

        let idsHilo = hilos.map(\.id)
        guard Set(idsHilo).count == idsHilo.count, !idsHilo.isEmpty else {
            throw ErrorLufy.contenidoIncompleto("hilos")
        }
        guard hilo(id: inicio.destacado) != nil else {
            throw ErrorLufy.contenidoIncompleto("destacado")
        }
        if let mencionado = historia.hiloMencionado {
            guard hilo(id: mencionado) != nil else {
                throw ErrorLufy.contenidoIncompleto("hiloMencionado")
            }
        }

        try validarCifras(archivo.cifras, exigenSello: false, origen: raiz)
        for cifra in archivo.cifras where cifra.sello != nil {
            throw ErrorLufy.contenidoIncompleto("sello en conteo")
        }
        try archivo.grafico.validar(origen: raiz)
        try validarBotones(inicio.formas + apoyo.formas)
        try validarLectura(datos.lectura + historia.sellos)

        for hilo in hilos {
            guard Fechas.isoValida(hilo.fecha) else { throw ErrorLufy.fechaInvalida(hilo.fecha) }
            try validarRuta(hilo.rutaWeb, origen: raiz)
            try hilo.fuenteTarjeta.validar(origen: raiz)
            try validarCifras(hilo.cifras, exigenSello: true, origen: raiz)
            try validarLectura(hilo.lectura)
            for bloque in hilo.bloques {
                try validar(bloque: bloque, origen: raiz)
            }
        }

        guard libro.paginas > 0, libro.precioSugeridoUSD > 0 else {
            throw ErrorLufy.contenidoIncompleto("libro")
        }
        guard libro.capitulos.count == libro.cantidadCapitulos, libro.capitulos.count == 14 else {
            throw ErrorLufy.contenidoIncompleto("capitulos")
        }
        for (indice, capitulo) in libro.capitulos.enumerated() {
            guard capitulo.numero == indice + 1 else {
                throw ErrorLufy.contenidoIncompleto("numero de capitulo")
            }
            guard capitulo.resumen.count < 800, capitulo.resumen.count > 40 else {
                throw ErrorLufy.contenidoIncompleto("resumen de capitulo")
            }
            guard !capitulo.titulo.isEmpty, !capitulo.periodo.isEmpty else {
                throw ErrorLufy.contenidoIncompleto("capitulo")
            }
        }
        let muestraJunta = libro.muestra.joined(separator: " ")
        guard muestraJunta.count < 800 else { throw ErrorLufy.contenidoIncompleto("muestra") }
        for hito in libro.linea {
            guard !hito.fecha.isEmpty, !hito.etiqueta.isEmpty, !hito.texto.isEmpty else {
                throw ErrorLufy.contenidoIncompleto("linea del libro")
            }
        }
        for cambio in historia.correcciones {
            guard Fechas.isoValida(cambio.fecha), !cambio.texto.isEmpty else {
                throw ErrorLufy.fechaInvalida(cambio.fecha)
            }
        }
        guard apoyo.metaParrafos.contains(where: { $0.contains("{{meta}}") }) else {
            throw ErrorLufy.contenidoIncompleto("meta")
        }
    }

    private func validar(bloque: Bloque, origen: String) throws {
        switch bloque {
        case .prosa(let prosa):
            guard !prosa.titulo.isEmpty, !prosa.parrafos.isEmpty else {
                throw ErrorLufy.contenidoIncompleto("prosa")
            }
            try prosa.fuente?.validar(origen: origen)
        case .aviso(let texto):
            guard !texto.isEmpty else { throw ErrorLufy.contenidoIncompleto("aviso") }
        case .lista(let lista):
            guard !lista.items.isEmpty else { throw ErrorLufy.contenidoIncompleto("lista") }
            try lista.fuente?.validar(origen: origen)
        case .grafico(let grafico):
            try grafico.validar(origen: origen)
        case .tabla(let tabla):
            guard !tabla.columnas.isEmpty, !tabla.filas.isEmpty else {
                throw ErrorLufy.contenidoIncompleto("tabla")
            }
            let titulos = tabla.columnas.map(\.titulo)
            guard Set(titulos).count == titulos.count else {
                throw ErrorLufy.contenidoIncompleto("columnas")
            }
            let ids = tabla.filas.map(\.id)
            guard Set(ids).count == ids.count else { throw ErrorLufy.contenidoIncompleto("filas") }
            for fila in tabla.filas where fila.celdas.count != tabla.columnas.count {
                throw ErrorLufy.contenidoIncompleto("celdas")
            }
            try tabla.fuente?.validar(origen: origen)
        case .columnas(let columnas):
            guard !columnas.izquierda.items.isEmpty, !columnas.derecha.items.isEmpty else {
                throw ErrorLufy.contenidoIncompleto("columnas")
            }
        case .tiempo(let tiempo):
            guard !tiempo.hitos.isEmpty else { throw ErrorLufy.contenidoIncompleto("tiempo") }
            for hito in tiempo.hitos {
                guard Fechas.isoValida(hito.fecha) else { throw ErrorLufy.fechaInvalida(hito.fecha) }
            }
            try tiempo.fuente?.validar(origen: origen)
        case .ficha(let ficha):
            guard !ficha.pares.isEmpty else { throw ErrorLufy.contenidoIncompleto("ficha") }
            let etiquetas = ficha.pares.map(\.etiqueta)
            guard Set(etiquetas).count == etiquetas.count else {
                throw ErrorLufy.contenidoIncompleto("ficha")
            }
        case .glosario(let glosario):
            guard !glosario.terminos.isEmpty else { throw ErrorLufy.contenidoIncompleto("glosario") }
        case .documentos(let documentos):
            guard !documentos.items.isEmpty else { throw ErrorLufy.contenidoIncompleto("documentos") }
            for item in documentos.items {
                try item.fuente.validar(origen: origen)
            }
            if let csv = documentos.csv {
                try validarRuta(csv, origen: origen)
            }
        case .cambios(let cambios):
            guard !cambios.items.isEmpty else { throw ErrorLufy.contenidoIncompleto("cambios") }
            for cambio in cambios.items {
                guard Fechas.isoValida(cambio.fecha) else { throw ErrorLufy.fechaInvalida(cambio.fecha) }
            }
        case .desconocido:
            break
        }
    }

    private func validarCifras(_ cifras: [Cifra], exigenSello: Bool, origen: String) throws {
        let ids = cifras.map(\.id)
        guard Set(ids).count == ids.count, !cifras.isEmpty else {
            throw ErrorLufy.contenidoIncompleto("cifras")
        }
        for cifra in cifras {
            guard !cifra.valor.isEmpty, !cifra.detalle.isEmpty else {
                throw ErrorLufy.contenidoIncompleto("cifra")
            }
            if exigenSello, cifra.sello == nil {
                throw ErrorLufy.contenidoIncompleto("sello")
            }
            try cifra.fuente.validar(origen: origen)
        }
    }

    private func validarLectura(_ notas: [NotaLectura]) throws {
        for nota in notas {
            if nota.ocr, nota.sello != nil {
                throw ErrorLufy.contenidoIncompleto("ocr")
            }
            guard !nota.texto.isEmpty else { throw ErrorLufy.contenidoIncompleto("lectura") }
        }
    }

    private func validarBotones(_ formas: [FormaApoyo]) throws {
        let permitidos: Set<String> = ["kofi", "libro", "muestra"]
        for forma in formas {
            for boton in [forma.boton, forma.botonSecundario].compactMap({ $0 }) {
                guard permitidos.contains(boton) else {
                    throw ErrorLufy.contenidoIncompleto("boton")
                }
            }
        }
    }

    private func validarRuta(_ ruta: String, origen: String) throws {
        guard PoliticaEnlaces.urlLufy(origen: origen, ruta: ruta) != nil else {
            throw ErrorLufy.enlaceProhibido(ruta)
        }
    }

    private static func cadenas(en datos: Data) throws -> [String] {
        let objeto: Any
        do {
            objeto = try JSONSerialization.jsonObject(with: datos)
        } catch {
            throw ErrorLufy.json(String(describing: error))
        }
        var salida: [String] = []
        func caminar(_ valor: Any) {
            switch valor {
            case let texto as String:
                salida.append(texto)
            case let lista as [Any]:
                lista.forEach(caminar)
            case let mapa as [String: Any]:
                mapa.values.forEach(caminar)
            default:
                break
            }
        }
        caminar(objeto)
        return salida
    }
}

extension Grafico {
    func validar(origen: String) throws {
        guard !titulo.isEmpty, !grupos.isEmpty else {
            throw ErrorLufy.contenidoIncompleto("grafico")
        }
        let nombres = grupos.map(\.nombre)
        guard Set(nombres).count == nombres.count else {
            throw ErrorLufy.contenidoIncompleto("grupos")
        }
        for grupo in grupos {
            guard !grupo.barras.isEmpty else { throw ErrorLufy.contenidoIncompleto("barras") }
            let etiquetas = grupo.barras.map(\.etiqueta)
            guard Set(etiquetas).count == etiquetas.count else {
                throw ErrorLufy.contenidoIncompleto("barras")
            }
            for barra in grupo.barras {
                guard barra.valor.isFinite, barra.valor >= 0, !barra.texto.isEmpty else {
                    throw ErrorLufy.contenidoIncompleto("barra")
                }
            }
        }
        try fuente?.validar(origen: origen)
    }
}
