import SwiftUI
import LufyCore

struct PantallaMas: View {
    var body: some View {
        List {
            NavigationLink {
                PantallaHistoria()
            } label: {
                Label(Seccion.historia.titulo, systemImage: Seccion.historia.simbolo)
            }
            NavigationLink {
                PantallaPrivacidad()
            } label: {
                Label(Seccion.privacidad.titulo, systemImage: Seccion.privacidad.simbolo)
            }
        }
        .navigationTitle("Más")
        .background(Color("Fondo"))
    }
}

struct PantallaInicio: View {
    @Environment(CatalogoTienda.self) private var tienda

    var body: some View {
        ContenidoListo { catalogo in
            ColumnaLectura {
                Cabecera(sobre: catalogo.inicio.sobre, titulo: catalogo.inicio.titulo, entradilla: catalogo.inicio.entradilla)
                VStack(alignment: .leading, spacing: 20) {
                    Text(catalogo.inicio.apoyo)
                        .font(.body)
                    if let meta = tienda.meta {
                        BarraMetaVista(meta: meta).tarjeta()
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(catalogo.inicio.pasos.enumerated()), id: \.offset) { indice, paso in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("\(indice + 1)")
                                    .font(.headline)
                                    .foregroundStyle(Color("TextoSobreOro"))
                                    .frame(width: 28, height: 28)
                                    .background(Color("Oro"), in: Circle())
                                    .accessibilityHidden(true)
                                Text(paso)
                            }
                        }
                    }
                    .tarjeta()
                    if let hilo = catalogo.hilo(id: catalogo.inicio.destacado) {
                        NavigationLink {
                            PantallaHilo(hiloID: hilo.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(hilo.tema)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color("Enlace"))
                                Text(hilo.titulo)
                                    .font(.system(.title3, design: .serif))
                                    .foregroundStyle(Color("Texto"))
                                Text(hilo.extracto)
                                    .font(.subheadline)
                                    .foregroundStyle(Color("Suave"))
                            }
                            .tarjeta()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Investigación destacada: \(hilo.titulo)")
                    }
                    Text("En qué se usa el apoyo")
                        .font(.system(.title2, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    ForEach(catalogo.inicio.usos) { uso in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(uso.titulo).font(.headline)
                            Text(uso.texto).font(.body)
                        }
                        .tarjeta()
                    }
                    ForEach(catalogo.inicio.formas) { forma in
                        FormaVista(forma: forma, catalogo: catalogo, rutaCompartir: catalogo.origen, mensaje: catalogo.textoCompartir)
                    }
                    ForEach(catalogo.inicio.principios) { principio in
                        PrincipioVista(principio: principio)
                    }
                    compartir(catalogo, ruta: catalogo.origen, mensaje: catalogo.textoCompartir)
                    EstadoCopia(origen: tienda.origenCatalogo)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle(Seccion.inicio.titulo)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct PantallaDatos: View {
    @Environment(CatalogoTienda.self) private var tienda

    var body: some View {
        ContenidoListo { catalogo in
            ColumnaLectura {
                Cabecera(sobre: "Archivo público", titulo: catalogo.datos.titulo, entradilla: catalogo.datos.entradilla)
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(catalogo.datos.lectura) { nota in
                        NotaLecturaVista(nota: nota)
                    }
                    Text(catalogo.archivo.titulo)
                        .font(.system(.title2, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    Text(catalogo.archivo.introduccion)
                    Text(catalogo.archivo.corte)
                        .font(.subheadline)
                        .foregroundStyle(Color("Suave"))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), alignment: .top)], spacing: 12) {
                        ForEach(catalogo.archivo.cifras) { cifra in
                            CifraTarjeta(cifra: cifra, origen: catalogo.origen)
                        }
                    }
                    if RecoleccionFuentes.todasFaltan(catalogo.archivo.cifras.map(\.fuente)) {
                        NotaSinCopia(texto: catalogo.notaSinCopia)
                    }
                    GraficoVista(grafico: catalogo.archivo.grafico, origen: catalogo.origen)
                    Text(catalogo.archivo.nota)
                        .font(.footnote)
                        .foregroundStyle(Color("Suave"))
                    Text("Investigaciones")
                        .font(.system(.title2, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    ForEach(catalogo.hilos) { hilo in
                        NavigationLink {
                            PantallaHilo(hiloID: hilo.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(hilo.fecha)
                                    .font(.caption)
                                    .foregroundStyle(Color("Suave"))
                                Text(hilo.titulo)
                                    .font(.headline)
                                    .foregroundStyle(Color("Texto"))
                                Text(hilo.extracto)
                                    .font(.subheadline)
                                    .foregroundStyle(Color("Suave"))
                            }
                            .tarjeta()
                        }
                        .buttonStyle(.plain)
                    }
                    Text(catalogo.datos.proximos)
                        .font(.body)
                    compartir(catalogo, ruta: catalogo.datos.rutaWeb, mensaje: catalogo.textoCompartir)
                    EstadoCopia(origen: tienda.origenCatalogo)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle(Seccion.datos.titulo)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct PantallaHilo: View {
    let hiloID: String
    @Environment(CatalogoTienda.self) private var tienda

    var body: some View {
        ContenidoListo { catalogo in
            if let hilo = catalogo.hilo(id: hiloID) {
                HiloLectura(hilo: hilo, catalogo: catalogo)
            } else {
                Text("Esta investigación ya no está en el índice.")
                    .padding()
            }
        }
        .navigationTitle("Investigación")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

private struct HiloLectura: View {
    let hilo: Hilo
    let catalogo: Catalogo
    @Environment(CatalogoTienda.self) private var tienda

    var body: some View {
        ColumnaLectura {
            Cabecera(sobre: hilo.tema, titulo: hilo.titulo, entradilla: hilo.entradilla)
            VStack(alignment: .leading, spacing: 20) {
                Text(hilo.fecha)
                    .font(.subheadline)
                    .foregroundStyle(Color("Suave"))
                ForEach(hilo.resumen, id: \.self) { parrafo in
                    Text(parrafo)
                }
                ForEach(hilo.lectura) { nota in
                    NotaLecturaVista(nota: nota)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), alignment: .top)], spacing: 12) {
                    ForEach(hilo.cifras) { cifra in
                        CifraTarjeta(cifra: cifra, origen: catalogo.origen)
                    }
                }
                ForEach(Array(hilo.bloques.enumerated()), id: \.offset) { _, bloque in
                    BloqueVista(bloque: bloque, origen: catalogo.origen)
                }
                FuenteVista(fuente: hilo.fuenteTarjeta, origen: catalogo.origen)
                if RecoleccionFuentes.todasFaltan(fuentes) {
                    NotaSinCopia(texto: catalogo.notaSinCopia)
                }
                compartir(catalogo, ruta: hilo.rutaWeb, mensaje: hilo.textoCompartir)
                EstadoCopia(origen: tienda.origenCatalogo)
            }
            .padding(.horizontal, 20)
        }
    }

    private var fuentes: [Fuente] {
        hilo.cifras.map(\.fuente) + [hilo.fuenteTarjeta] + hilo.bloques.flatMap(RecoleccionFuentes.de)
    }
}

struct PantallaLibro: View {
    @Environment(CatalogoTienda.self) private var tienda

    var body: some View {
        ContenidoListo { catalogo in
            ColumnaLectura {
                Cabecera(sobre: catalogo.libro.sobre, titulo: catalogo.libro.titulo, entradilla: catalogo.libro.entradilla)
                VStack(alignment: .leading, spacing: 20) {
                    PortadaLibro(libro: catalogo.libro)
                        .frame(maxWidth: .infinity)
                    Text(catalogo.libro.ficha)
                        .font(.subheadline)
                        .foregroundStyle(Color("Suave"))
                    Text(catalogo.libro.pago)
                    Text("\(catalogo.libro.paginas) páginas · \(catalogo.libro.cantidadCapitulos) capítulos · sugerido \(catalogo.libro.precioSugeridoUSD) USD")
                        .font(.headline)
                    AvisoPagoApagado()
                    if let forma = catalogo.apoyo.formas.first(where: { $0.id == "libro" }) {
                        BotonesForma(forma: forma, catalogo: catalogo)
                    } else {
                        BotonToken(token: "libro", catalogo: catalogo)
                        BotonToken(token: "muestra", catalogo: catalogo)
                    }
                    seccion(catalogo.libro.historiaTitulo, catalogo.libro.historia)
                    Text(catalogo.libro.lineaTitulo)
                        .font(.system(.title2, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    Text(catalogo.libro.lineaIntro)
                    ForEach(catalogo.libro.linea) { hito in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(hito.etiqueta).font(.headline)
                            Text(hito.texto).font(.body)
                        }
                        .tarjeta()
                    }
                    Text(catalogo.libro.capitulosTitulo)
                        .font(.system(.title2, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    Text(catalogo.libro.antesDeEmpezar)
                        .font(.subheadline)
                        .foregroundStyle(Color("Suave"))
                    Text(catalogo.libro.capitulosIntro)
                    ForEach(catalogo.libro.capitulos) { capitulo in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(capitulo.periodo)
                                .font(.caption)
                                .foregroundStyle(Color("Suave"))
                            Text(capitulo.titulo)
                                .font(.headline)
                            Text(capitulo.resumen)
                                .font(.body)
                        }
                        .tarjeta()
                    }
                    seccion(catalogo.libro.hechoTitulo, catalogo.libro.hecho)
                    Text(catalogo.libro.aviso)
                        .font(.footnote)
                        .foregroundStyle(Color("Suave"))
                    seccion(catalogo.libro.paraQuienTitulo, catalogo.libro.paraQuien)
                    seccion(catalogo.libro.edicionTitulo, catalogo.libro.edicion)
                    Text(catalogo.libro.muestraTitulo)
                        .font(.system(.title2, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    ForEach(catalogo.libro.muestra, id: \.self) { parrafo in
                        Text(parrafo)
                    }
                    compartir(catalogo, ruta: catalogo.libro.rutaWeb, mensaje: catalogo.libro.textoCompartir)
                    EstadoCopia(origen: tienda.origenCatalogo)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle(Seccion.libro.titulo)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private func seccion(_ titulo: String, _ parrafos: [String]) -> some View {
        Text(titulo)
            .font(.system(.title2, design: .serif))
            .accessibilityAddTraits(.isHeader)
        ForEach(parrafos, id: \.self) { parrafo in
            Text(parrafo)
        }
    }
}

struct PortadaLibro: View {
    let libro: Libro

    var body: some View {
        VStack(spacing: 14) {
            Balanza()
                .stroke(Color("Oro"), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .frame(width: 84, height: 84)
                .accessibilityHidden(true)
            Text("LUFY")
                .font(.caption.weight(.bold))
                .tracking(3)
                .foregroundStyle(Color("Oro"))
            Text(libro.titulo)
                .font(.system(.title3, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("TextoSobreVino"))
            Text(libro.subtitulo)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("OroSuave"))
        }
        .padding(24)
        .frame(width: 230)
        .background(Color("Vino"), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Portada. \(libro.titulo). \(libro.subtitulo)")
    }
}

struct PantallaApoyo: View {
    @Environment(CatalogoTienda.self) private var tienda

    var body: some View {
        ContenidoListo { catalogo in
            ColumnaLectura {
                Cabecera(sobre: catalogo.apoyo.sobre, titulo: catalogo.apoyo.titulo, entradilla: catalogo.apoyo.entradilla)
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(catalogo.apoyo.porque, id: \.self) { linea in
                        Text(linea)
                    }
                    Text(catalogo.apoyo.usosIntro)
                    ForEach(catalogo.apoyo.usos) { uso in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(uso.titulo).font(.headline)
                            Text(uso.texto)
                        }
                        .tarjeta()
                    }
                    Text(catalogo.archivo.tituloApoyo)
                        .font(.system(.title2, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    Text(catalogo.archivo.introduccionApoyo)
                    GraficoVista(grafico: catalogo.archivo.grafico, origen: catalogo.origen)
                    Text(catalogo.archivo.notaGraficoApoyo)
                        .font(.footnote)
                        .foregroundStyle(Color("Suave"))
                    Text(catalogo.apoyo.metaTitulo)
                        .font(.system(.title2, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    Text(catalogo.apoyo.metaSobre)
                        .font(.subheadline)
                        .foregroundStyle(Color("Suave"))
                    if let meta = tienda.meta {
                        BarraMetaVista(meta: meta).tarjeta()
                    }
                    ForEach(catalogo.apoyo.metaParrafos, id: \.self) { parrafo in
                        Text(textoConMeta(parrafo, meta: tienda.meta))
                    }
                    Text(catalogo.apoyo.metaNota)
                        .font(.footnote)
                        .foregroundStyle(Color("Suave"))
                    Text(catalogo.apoyo.formasTitulo)
                        .font(.system(.title2, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    AvisoPagoApagado()
                    ForEach(catalogo.apoyo.formas) { forma in
                        FormaVista(forma: forma, catalogo: catalogo, rutaCompartir: catalogo.apoyo.rutaWeb, mensaje: catalogo.textoCompartir)
                    }
                    Text(catalogo.apoyo.principiosTitulo)
                        .font(.system(.title2, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    ForEach(catalogo.apoyo.principios) { principio in
                        PrincipioVista(principio: principio)
                    }
                    Text(catalogo.apoyo.pie)
                        .font(.footnote)
                        .foregroundStyle(Color("Suave"))
                    compartir(catalogo, ruta: catalogo.apoyo.rutaWeb, mensaje: catalogo.textoCompartir)
                    EstadoCopia(origen: tienda.origenCatalogo)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle(Seccion.apoya.titulo)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct PantallaHistoria: View {
    @Environment(CatalogoTienda.self) private var tienda

    var body: some View {
        ContenidoListo { catalogo in
            ColumnaLectura {
                Cabecera(sobre: "Lufy", titulo: catalogo.historia.titulo, entradilla: catalogo.historia.entradilla)
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(catalogo.historia.secciones) { seccion in
                        Text(seccion.titulo)
                            .font(.system(.title2, design: .serif))
                            .accessibilityAddTraits(.isHeader)
                        ForEach(seccion.parrafos, id: \.self) { parrafo in
                            Text(parrafo)
                        }
                    }
                    Text("Sellos")
                        .font(.system(.title2, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    ForEach(catalogo.historia.sellos) { nota in
                        NotaLecturaVista(nota: nota).tarjeta()
                    }
                    Text("Reglas")
                        .font(.system(.title2, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    ForEach(catalogo.historia.reglas, id: \.self) { regla in
                        Text(regla)
                    }
                    Text("Fuentes")
                        .font(.system(.title2, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    ForEach(catalogo.historia.fuentes, id: \.self) { fuente in
                        Text(fuente)
                    }
                    Text(catalogo.historia.notaFuentes)
                        .font(.footnote)
                        .foregroundStyle(Color("Suave"))
                    Text("Correcciones")
                        .font(.system(.title2, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    Text(catalogo.historia.introCorrecciones)
                    ForEach(catalogo.historia.correcciones) { cambio in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cambio.etiqueta).font(.headline)
                            Text(cambio.texto)
                        }
                        .tarjeta()
                    }
                    Text(catalogo.historia.contacto)
                    if Configuracion.mostrarEnlacesKoFi {
                        BotonToken(token: "kofi", catalogo: catalogo)
                    }
                    compartir(catalogo, ruta: catalogo.historia.rutaWeb, mensaje: catalogo.textoCompartir)
                    EstadoCopia(origen: tienda.origenCatalogo)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle(Seccion.historia.titulo)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct PantallaPrivacidad: View {
    @Environment(CatalogoTienda.self) private var tienda

    var body: some View {
        ContenidoListo { catalogo in
            ColumnaLectura {
                Cabecera(
                    sobre: catalogo.privacidad.etiquetaActualizado,
                    titulo: catalogo.privacidad.titulo,
                    entradilla: nil
                )
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(catalogo.privacidad.puntos) { punto in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(punto.titulo).font(.headline)
                            Text(punto.texto)
                        }
                        .tarjeta()
                    }
                    Text("La app no tiene cuentas, analítica ni rastreadores.")
                        .font(.footnote)
                        .foregroundStyle(Color("Suave"))
                    compartir(catalogo, ruta: catalogo.privacidad.rutaWeb, mensaje: catalogo.textoCompartir)
                    EstadoCopia(origen: tienda.origenCatalogo)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle(Seccion.privacidad.titulo)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

private struct FormaVista: View {
    let forma: FormaApoyo
    let catalogo: Catalogo
    let rutaCompartir: String
    let mensaje: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(forma.titulo).font(.headline)
            ForEach(forma.parrafos, id: \.self) { parrafo in
                Text(parrafo)
            }
            BotonesForma(forma: forma, catalogo: catalogo)
            if forma.id == "compartir" {
                compartir(catalogo, ruta: rutaCompartir, mensaje: mensaje)
            }
        }
        .tarjeta()
    }
}

private struct PrincipioVista: View {
    let principio: Principio

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(principio.titulo).font(.headline)
            Text(principio.texto)
            if !principio.sellos.isEmpty {
                HStack(spacing: 6) {
                    ForEach(principio.sellos, id: \.self) { sello in
                        PastillaSello(sello: sello)
                    }
                }
                .accessibilityElement(children: .contain)
            }
        }
        .tarjeta()
    }
}

@ViewBuilder
private func compartir(_ catalogo: Catalogo, ruta: String, mensaje: String) -> some View {
    if let url = EnlacesVista.pagina(catalogo, ruta: ruta) {
        CompartirLufy(url: url, mensaje: mensaje)
    }
}

struct BloqueVista: View {
    let bloque: Bloque
    let origen: String

    var body: some View {
        switch bloque {
        case .prosa(let prosa):
            VStack(alignment: .leading, spacing: 8) {
                Text(prosa.titulo)
                    .font(.system(.title3, design: .serif))
                    .accessibilityAddTraits(.isHeader)
                ForEach(prosa.parrafos, id: \.self) { parrafo in
                    Text(parrafo)
                }
                if let fuente = prosa.fuente {
                    FuenteVista(fuente: fuente, origen: origen)
                }
            }
        case .aviso(let texto):
            Text(texto)
                .font(.body)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color("Saber"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(Color("TextoSobreVino"))
        case .lista(let lista):
            VStack(alignment: .leading, spacing: 8) {
                Text(lista.titulo).font(.headline).accessibilityAddTraits(.isHeader)
                ForEach(lista.items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("·").accessibilityHidden(true)
                        Text(item)
                    }
                }
                if let fuente = lista.fuente {
                    FuenteVista(fuente: fuente, origen: origen)
                }
            }
            .tarjeta()
        case .grafico(let grafico):
            GraficoVista(grafico: grafico, origen: origen)
        case .tabla(let tabla):
            TablaVista(tabla: tabla, origen: origen)
        case .columnas(let columnas):
            VStack(alignment: .leading, spacing: 8) {
                Text(columnas.titulo).font(.headline).accessibilityAddTraits(.isHeader)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        columna(columnas.izquierda)
                        columna(columnas.derecha)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        columna(columnas.izquierda)
                        columna(columnas.derecha)
                    }
                }
            }
            .tarjeta()
        case .tiempo(let tiempo):
            VStack(alignment: .leading, spacing: 8) {
                Text(tiempo.titulo).font(.headline).accessibilityAddTraits(.isHeader)
                if let intro = tiempo.introduccion { Text(intro) }
                ForEach(tiempo.hitos) { hito in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(hito.etiqueta).font(.subheadline.weight(.semibold))
                        Text(hito.texto)
                    }
                }
                if let fuente = tiempo.fuente {
                    FuenteVista(fuente: fuente, origen: origen)
                }
            }
            .tarjeta()
        case .ficha(let ficha):
            VStack(alignment: .leading, spacing: 8) {
                Text(ficha.titulo).font(.headline).accessibilityAddTraits(.isHeader)
                ForEach(ficha.pares) { par in
                    LabeledContent(par.etiqueta, value: par.valor)
                }
                ForEach(ficha.notas, id: \.self) { nota in
                    Text(nota).font(.footnote).foregroundStyle(Color("Suave"))
                }
            }
            .tarjeta()
        case .glosario(let glosario):
            VStack(alignment: .leading, spacing: 8) {
                Text(glosario.titulo).font(.headline).accessibilityAddTraits(.isHeader)
                ForEach(glosario.terminos) { termino in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(termino.termino).font(.subheadline.weight(.semibold))
                        Text(termino.definicion)
                    }
                }
            }
            .tarjeta()
        case .documentos(let documentos):
            VStack(alignment: .leading, spacing: 10) {
                Text(documentos.titulo).font(.headline).accessibilityAddTraits(.isHeader)
                Text(documentos.introduccion)
                ForEach(documentos.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.institucion).font(.caption).foregroundStyle(Color("Suave"))
                        Text(item.titulo).font(.subheadline.weight(.semibold))
                        FuenteVista(fuente: item.fuente, origen: origen)
                    }
                }
                if let csv = documentos.csv {
                    EnlacePagina(origen: origen, ruta: csv, titulo: "Abrir la tabla en Lufy")
                }
            }
            .tarjeta()
        case .cambios(let cambios):
            VStack(alignment: .leading, spacing: 8) {
                Text(cambios.titulo).font(.headline).accessibilityAddTraits(.isHeader)
                ForEach(cambios.items) { cambio in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cambio.etiqueta).font(.subheadline.weight(.semibold))
                        Text(cambio.texto)
                    }
                }
                if let cierre = cambios.cierre {
                    Text(cierre).font(.footnote).foregroundStyle(Color("Suave"))
                }
            }
            .tarjeta()
        case .desconocido:
            EmptyView()
        }
    }

    private func columna(_ columna: Columna) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(columna.titulo).font(.subheadline.weight(.semibold))
            ForEach(columna.items, id: \.self) { item in
                Text(item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GraficoVista: View {
    let grafico: Grafico
    let origen: String
    @Environment(\.accessibilityReduceMotion) private var reducir

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(grafico.titulo)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(grafico.grupos) { grupo in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(grupo.nombre).font(.subheadline.weight(.semibold))
                        if grupo.ocr { MarcaOCR() }
                    }
                    ForEach(grupo.barras) { barra in
                        BarraGrafico(
                            fraccion: grafico.fraccion(grupo: grupo, barra: barra),
                            barra: barra,
                            animar: !reducir
                        )
                    }
                }
            }
            if !grafico.leyenda.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(grafico.leyenda.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color(item.tono))
                                .frame(width: 18, height: 10)
                                .accessibilityHidden(true)
                            Text(item.etiqueta).font(.caption)
                        }
                    }
                }
            }
            if !grafico.nota.isEmpty {
                Text(grafico.nota)
                    .font(.footnote)
                    .foregroundStyle(Color("Suave"))
            }
            if let fuente = grafico.fuente {
                FuenteVista(fuente: fuente, origen: origen)
            }
        }
        .tarjeta()
    }

    private func color(_ tono: TonoBarra) -> Color {
        switch tono {
        case .oro, .oroRaya: Color("Oro")
        case .vino, .vinoRaya: Color("Vino")
        case .tinta, .punto: Color("Texto")
        }
    }
}

private struct BarraGrafico: View {
    let fraccion: Double
    let barra: Barra
    let animar: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(barra.etiqueta).font(.caption)
                Spacer()
                Text(barra.texto).font(.caption.monospacedDigit())
            }
            if barra.tono == .punto {
                Circle()
                    .fill(Color("Texto"))
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
            } else {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color("Papel2"))
                        Capsule()
                            .fill(relleno)
                            .frame(width: max(4, geo.size.width * fraccion))
                            .overlay {
                                if barra.tono == .oroRaya || barra.tono == .vinoRaya {
                                    Rayas().clipShape(Capsule())
                                }
                            }
                    }
                }
                .frame(height: 12)
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(barra.etiqueta): \(barra.texto)")
        .animation(animar ? .easeOut(duration: 0.35) : nil, value: fraccion)
    }

    private var relleno: Color {
        switch barra.tono {
        case .oro, .oroRaya: Color("Oro")
        case .vino, .vinoRaya: Color("Vino")
        case .tinta, .punto: Color("Texto")
        }
    }
}

private struct Rayas: View {
    var body: some View {
        GeometryReader { geo in
            Path { camino in
                let paso: CGFloat = 7
                var x = -geo.size.height
                while x < geo.size.width {
                    camino.move(to: CGPoint(x: x, y: geo.size.height))
                    camino.addLine(to: CGPoint(x: x + geo.size.height, y: 0))
                    x += paso
                }
            }
            .stroke(Color("TextoSobreVino").opacity(0.45), lineWidth: 1)
        }
    }
}

struct TablaVista: View {
    let tabla: Tabla
    let origen: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tabla.titulo).font(.headline).accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        ForEach(tabla.columnas) { columna in
                            Text(columna.titulo)
                                .font(.caption.weight(.semibold))
                                .frame(minWidth: 88, alignment: columna.numerica ? .trailing : .leading)
                        }
                    }
                    ForEach(tabla.filas) { fila in
                        GridRow {
                            ForEach(Array(fila.celdas.enumerated()), id: \.offset) { indice, celda in
                                HStack(spacing: 4) {
                                    Text(celda)
                                        .font(.caption)
                                    if indice == 0, fila.ocr {
                                        MarcaOCR()
                                    }
                                }
                                .frame(
                                    minWidth: 88,
                                    alignment: (indice < tabla.columnas.count && tabla.columnas[indice].numerica) ? .trailing : .leading
                                )
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(fila.celdas.joined(separator: ", "))
                    }
                }
                .padding(.vertical, 4)
            }
            .accessibilityHint("Desliza en horizontal para ver todas las columnas")
            if let nota = tabla.nota, !nota.isEmpty {
                Text(nota).font(.footnote).foregroundStyle(Color("Suave"))
            }
            if let fuente = tabla.fuente {
                FuenteVista(fuente: fuente, origen: origen)
            }
        }
        .tarjeta()
    }
}

private struct EnlacePagina: View {
    let origen: String
    let ruta: String
    let titulo: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let url = PoliticaEnlaces.urlLufy(origen: origen, ruta: ruta) {
            Button(titulo) { openURL(url) }
                .frame(minHeight: 44)
                .accessibilityHint("Abre una página de Lufy")
        }
    }
}
