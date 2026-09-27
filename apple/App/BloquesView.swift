import LufyCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct PaginaView: View {
    var pagina: Pagina
    var ancla: String?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                MarcoLectura {
                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(pagina.secciones) { seccion in
                            SeccionVista(seccion: seccion)
                        }
                        PieLufy()
                    }
                }
            }
            .onAppear {
                guard let ancla else { return }
                Task { proxy.scrollTo(ancla, anchor: .top) }
            }
        }
        .background(Paleta.fondo(scheme).ignoresSafeArea())
        .barraLufy(pagina.titulo)
    }
}

struct SeccionVista: View {
    let seccion: Seccion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let titulo = seccion.titulo, !ocultaTitulo {
                TituloSeccion(texto: titulo)
            }
            ForEach(Array(seccion.bloques.enumerated()), id: \.offset) { _, bloque in
                BloqueVista(bloque: bloque)
            }
        }
        .id(seccion.id)
    }

    private var ocultaTitulo: Bool {
        guard let primero = seccion.bloques.first else { return false }
        switch primero {
        case .hero, .saber, .archivoPublico:
            return true
        default:
            return false
        }
    }
}

struct BloqueVista: View {
    let bloque: Bloque
    @Environment(ModeloApp.self) private var modelo
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var tamano

    var body: some View {
        switch bloque {
        case .prosa(let parrafos):
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(parrafos.enumerated()), id: \.offset) { _, parrafo in
                    textoRico(parrafo)
                        .font(.body)
                        .foregroundStyle(Paleta.texto(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        case .lista(let items, let ordenada):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { indice, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(ordenada ? "\(indice + 1)." : "•")
                            .font(.body.weight(.bold))
                            .foregroundStyle(Paleta.oro)
                            .accessibilityHidden(true)
                        textoRico(item)
                            .font(.body)
                            .foregroundStyle(Paleta.texto(scheme))
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        case .saber(let titulo, let items):
            VStack(alignment: .leading, spacing: 14) {
                Text(titulo)
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .foregroundStyle(Paleta.papel)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(items.enumerated()), id: \.offset) { indice, item in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(indice + 1)")
                            .font(.body.weight(.bold))
                            .foregroundStyle(Paleta.tinta)
                            .frame(width: 32, height: 32)
                            .background(Paleta.oro, in: Circle())
                            .accessibilityHidden(true)
                        textoRico(item)
                            .font(.body)
                            .foregroundStyle(Paleta.papel)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Paleta.saber(scheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        case .cifras(let cifras):
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                ForEach(Array(cifras.enumerated()), id: \.offset) { _, cifra in
                    CifraTarjeta(cifra: cifra)
                }
            }
        case .grafico(let grafico):
            GraficoVista(grafico: grafico)
        case .comparaciones(let comparaciones):
            ComparacionesVista(comparaciones: comparaciones)
        case .tabla(let tabla):
            TablaVista(tabla: tabla)
        case .aviso(let texto):
            textoRico(texto)
                .font(.body)
                .foregroundStyle(Paleta.texto(scheme))
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Paleta.oro.opacity(scheme == .dark ? 0.16 : 0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .leading) {
                    Rectangle().fill(Paleta.oro).frame(width: 4)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("Aviso. \(texto)")
        case .columnas(let izquierda, let derecha):
            let columnas = HStack(alignment: .top, spacing: 12) {
                ColumnaVista(columna: izquierda, acento: Paleta.ok)
                ColumnaVista(columna: derecha, acento: Paleta.abierto)
            }
            if tamano == .compact {
                VStack(alignment: .leading, spacing: 12) {
                    ColumnaVista(columna: izquierda, acento: Paleta.ok)
                    ColumnaVista(columna: derecha, acento: Paleta.abierto)
                }
            } else {
                columnas
            }
        case .ficha(let pares):
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(Array(pares.enumerated()), id: \.offset) { _, par in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(par.termino)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Paleta.suave(scheme))
                            .textCase(.uppercase)
                        Text(par.valor)
                            .font(.system(.title3, design: .serif))
                            .foregroundStyle(Paleta.texto(scheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Paleta.superficie(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
            }
        case .glosario(let entradas):
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(entradas.enumerated()), id: \.offset) { _, entrada in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entrada.termino).font(.body.weight(.bold))
                        Text(entrada.definicion).foregroundStyle(Paleta.suave(scheme))
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) { Rectangle().fill(Paleta.borde(scheme)).frame(height: 1) }
                    .accessibilityElement(children: .combine)
                }
            }
        case .tiempo(let eventos):
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(eventos.enumerated()), id: \.offset) { _, evento in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle().fill(Paleta.oro).frame(width: 12, height: 12)
                                .overlay(Circle().strokeBorder(Paleta.vino, lineWidth: 2))
                            Rectangle().fill(Paleta.oro).frame(width: 3).frame(maxHeight: .infinity)
                        }
                        .frame(width: 16)
                        .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(evento.fecha)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Paleta.abierto)
                            Text(evento.texto)
                                .foregroundStyle(Paleta.texto(scheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.bottom, 16)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        case .documentos(let intro, let items):
            VStack(alignment: .leading, spacing: 12) {
                Text(intro)
                    .foregroundStyle(Paleta.suave(scheme))
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    FuenteLinea(fuente: Fuente(
                        institucion: item.institucion,
                        documento: item.documento,
                        fecha: item.fecha,
                        archivo: item.archivo
                    ))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Paleta.superficie(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .leading) { Rectangle().fill(Paleta.oro).frame(width: 4) }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        case .leyenda(let items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 6) {
                        if let sello = item.sello {
                            SelloVista(sello: sello)
                        } else if item.marca == "OCR" {
                            MarcaOCR()
                        }
                        Text(item.texto)
                            .foregroundStyle(Paleta.texto(scheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Paleta.superficie(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Paleta.borde(scheme)))
                }
            }
        case .tarjetas(let tarjetas):
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                ForEach(Array(tarjetas.enumerated()), id: \.offset) { _, tarjeta in
                    TarjetaVista(tarjeta: tarjeta)
                }
            }
        case .fuente(let fuente):
            FuenteLinea(fuente: fuente)
        case .enlace(let titulo, let destino):
            if let ruta = destino.ruta {
                NavigationLink(value: ruta) {
                    Text(titulo)
                        .font(.body.weight(.semibold))
                        .frame(minHeight: 44, alignment: .leading)
                }
            }
        case .botonKoFi(let titulo, let cual):
            if let contenido = modelo.contenido, let url = Ajustes.enlaceKoFi(contenido.enlaces.url(cual)) {
                Link(destination: url) {
                    EtiquetaBoton(titulo: titulo, estilo: .principal)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Se abre fuera de la app, en Ko-fi.")
            }
        case .metaCerebro:
            MetaCerebroVista()
        case .archivoPublico(let titulo):
            if let archivo = modelo.contenido?.archivo {
                ArchivoVista(archivo: archivo, titulo: titulo ?? archivo.titulo)
            }
        case .listaHilos:
            if let hilos = modelo.contenido?.hilos {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(hilos) { hilo in
                        NavigationLink(value: Ruta.hilo(hilo.id)) {
                            HiloResumen(hilo: hilo)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        case .hero(let hero):
            HeroVista(hero: hero)
        }
    }
}

struct HeroVista: View {
    let hero: Hero
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hero.sobre)
                .font(.caption.weight(.heavy))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Paleta.abierto)
            Text(hero.titulo)
                .font(.system(.largeTitle, design: .serif).weight(.bold))
                .foregroundStyle(Paleta.texto(scheme))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(hero.entradilla)
                .font(.title3)
                .foregroundStyle(Paleta.suave(scheme))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(hero.parrafos.enumerated()), id: \.offset) { _, parrafo in
                Text(parrafo)
                    .foregroundStyle(Paleta.texto(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !hero.acciones.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(hero.acciones.enumerated()), id: \.offset) { _, accion in
                        if let ruta = accion.destino.ruta {
                            NavigationLink(value: ruta) {
                                EtiquetaBoton(titulo: accion.titulo, estilo: accion.estilo)
                            }
                            .buttonStyle(.plain)
                        } else if case .koFi(let cual) = accion.destino {
                            BotonKoFi(titulo: accion.titulo, cual: cual, estilo: accion.estilo)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

struct BotonKoFi: View {
    var titulo: String
    var cual: CualKoFi
    var estilo: EstiloBoton
    @Environment(ModeloApp.self) private var modelo

    var body: some View {
        if let contenido = modelo.contenido, let url = Ajustes.enlaceKoFi(contenido.enlaces.url(cual)) {
            Link(destination: url) {
                EtiquetaBoton(titulo: titulo, estilo: estilo)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Se abre fuera de la app, en Ko-fi.")
        }
    }
}

struct CifraTarjeta: View {
    let cifra: Cifra
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let sello = cifra.sello { SelloVista(sello: sello) }
                if cifra.ocr == true { MarcaOCR() }
            }
            Text(cifra.valor)
                .font(.system(.title, design: .serif).weight(.bold))
                .foregroundStyle(Paleta.texto(scheme))
                .fixedSize(horizontal: false, vertical: true)
            Text(cifra.detalle)
                .font(.body)
                .foregroundStyle(Paleta.texto(scheme))
                .fixedSize(horizontal: false, vertical: true)
            if let fuente = cifra.fuente {
                FuenteLinea(fuente: fuente)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Paleta.superficie(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .leading) { Rectangle().fill(Paleta.oro).frame(width: 4) }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Paleta.borde(scheme)))
    }
}

struct FuenteLinea: View {
    let fuente: Fuente
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let referencia = fuente.referencia {
                NavigationLink(value: Ruta.archivo(referencia)) {
                    Text(fuente.linea)
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                Text("Copia en Lufy · SHA-256 \(agrupar(referencia.sha256)) · archivada el \(referencia.archivado)")
                    .font(.caption)
                    .textSelection(.enabled)
                .accessibilityLabel("Abre la copia archivada en Lufy. Huella SHA-256. Archivada el \(referencia.archivado).")
            } else {
                Text(fuente.linea)
                    .font(.footnote)
                    .textSelection(.enabled)
                    .accessibilityLabel("Fuente, sin enlace fuera de Lufy. \(fuente.linea)")
            }
        }
        .foregroundStyle(Paleta.suave(scheme))
        .contextMenu {
            Button("Copiar la fuente") { Portapapeles.copiar(fuente.linea) }
        }
    }

    private func agrupar(_ huella: String) -> String {
        stride(from: 0, to: huella.count, by: 4).map { inicio in
            let desde = huella.index(huella.startIndex, offsetBy: inicio)
            let hasta = huella.index(desde, offsetBy: min(4, huella.distance(from: desde, to: huella.endIndex)))
            return String(huella[desde..<hasta])
        }.joined(separator: " ")
    }
}

struct GraficoVista: View {
    let grafico: Grafico
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let maximo = EscalaBarras.maximo(grafico.barras.map(\.numero))
        VStack(alignment: .leading, spacing: 12) {
            Text(grafico.titulo)
                .font(.headline)
                .foregroundStyle(Paleta.texto(scheme))
            Text(grafico.nota)
                .font(.footnote)
                .foregroundStyle(Paleta.suave(scheme))
                .fixedSize(horizontal: false, vertical: true)
            if let leyenda = grafico.leyenda, !leyenda.isEmpty {
                LeyendaVista(items: leyenda)
            }
            ForEach(Array(grafico.barras.enumerated()), id: \.offset) { _, barra in
                BarraFila(barra: barra, maximo: maximo)
            }
        }
        .padding(14)
        .background(Paleta.superficie(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Paleta.borde(scheme)))
    }
}

struct ComparacionesVista: View {
    let comparaciones: Comparaciones
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(comparaciones.titulo).font(.headline).foregroundStyle(Paleta.texto(scheme))
            Text(comparaciones.nota)
                .font(.footnote)
                .foregroundStyle(Paleta.suave(scheme))
                .fixedSize(horizontal: false, vertical: true)
            LeyendaVista(items: comparaciones.leyenda)
            ForEach(Array(comparaciones.grupos.enumerated()), id: \.offset) { _, grupo in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(grupo.nombre).font(.body.weight(.bold))
                        if grupo.ocr == true { MarcaOCR() }
                    }
                    let maximo = EscalaBarras.maximo(grupo.filas.map(\.numero))
                    ForEach(Array(grupo.filas.enumerated()), id: \.offset) { _, fila in
                        BarraFila(barra: fila, maximo: maximo)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(14)
        .background(Paleta.superficie(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Paleta.borde(scheme)))
    }
}

struct LeyendaVista: View {
    let items: [LeyendaItem]
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Paleta.relleno(item.estilo, scheme))
                        .frame(width: 18, height: 8)
                        .accessibilityHidden(true)
                    Text(item.etiqueta).font(.caption)
                }
            }
        }
        .foregroundStyle(Paleta.suave(scheme))
        .accessibilityElement(children: .combine)
    }
}

struct BarraFila: View {
    let barra: Barra
    let maximo: Double
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Text(barra.etiqueta)
                    if barra.ocr == true { MarcaOCR() }
                }
                Spacer(minLength: 8)
                Text(barra.texto)
                    .font(.body.weight(.bold))
                    .monospacedDigit()
            }
            .font(.subheadline)
            .foregroundStyle(Paleta.texto(scheme))
            GeometryReader { geo in
                let fraccion = EscalaBarras.fraccion(barra.numero, maximo: maximo)
                let ancho = geo.size.width * fraccion
                ZStack(alignment: .leading) {
                    Capsule().fill(Paleta.pista(scheme))
                    Capsule()
                        .fill(Paleta.relleno(barra.estilo, scheme))
                        .frame(width: ancho)
                    if barra.estilo == .vinoRayado || barra.estilo == .oroRayado {
                        Rayado()
                            .frame(width: ancho)
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(height: 10)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(barra.etiqueta), \(barra.texto)")
    }
}

struct Rayado: View {
    var body: some View {
        Canvas { contexto, size in
            var camino = Path()
            let paso: CGFloat = 7
            var x: CGFloat = -size.height
            while x < size.width {
                camino.move(to: CGPoint(x: x, y: size.height))
                camino.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += paso
            }
            contexto.stroke(camino, with: .color(Color.white.opacity(0.45)), lineWidth: 2)
        }
        .accessibilityHidden(true)
    }
}

struct TablaVista: View {
    let tabla: Tabla
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tabla.titulo)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Paleta.texto(scheme))
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(tabla.columnas.enumerated()), id: \.offset) { indice, columna in
                            Text(columna)
                                .font(.caption.weight(.bold))
                                .frame(width: ancho(indice), alignment: indice == 0 ? .leading : .trailing)
                                .padding(8)
                        }
                    }
                    .background(Paleta.pista(scheme))
                    ForEach(Array(tabla.filas.enumerated()), id: \.offset) { indiceFila, fila in
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(Array(fila.celdas.enumerated()), id: \.offset) { indice, celda in
                                HStack(spacing: 6) {
                                    if indice == 0, fila.ocr == true { MarcaOCR() }
                                    Text(celda)
                                        .font(.footnote)
                                        .multilineTextAlignment(indice == 0 ? .leading : .trailing)
                                }
                                .frame(width: ancho(indice), alignment: indice == 0 ? .leading : .trailing)
                                .padding(8)
                            }
                        }
                        .background(indiceFila.isMultiple(of: 2) ? Color.clear : Paleta.pista(scheme).opacity(0.45))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(etiqueta(fila))
                    }
                }
            }
            .accessibilityLabel(tabla.titulo)
            if let nota = tabla.nota {
                Text(nota)
                    .font(.footnote)
                    .foregroundStyle(Paleta.suave(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func ancho(_ indice: Int) -> CGFloat { indice == 0 ? 230 : 168 }

    private func etiqueta(_ fila: FilaTabla) -> String {
        zip(tabla.columnas, fila.celdas).map { "\($0): \($1)" }.joined(separator: ". ")
    }
}

struct ColumnaVista: View {
    let columna: ColumnaTexto
    let acento: Color
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(columna.titulo)
                .font(.headline)
                .foregroundStyle(Paleta.texto(scheme))
            ForEach(Array(columna.items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•").accessibilityHidden(true)
                    Text(item).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Paleta.superficie(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .top) { Rectangle().fill(acento).frame(height: 4) }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Paleta.borde(scheme)))
    }
}

struct TarjetaVista: View {
    let tarjeta: Tarjeta
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let meta = tarjeta.meta {
                Text(meta)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Paleta.suave(scheme))
            }
            Text(tarjeta.titulo)
                .font(.system(.title3, design: .serif).weight(.bold))
                .foregroundStyle(Paleta.texto(scheme))
                .fixedSize(horizontal: false, vertical: true)
            textoRico(tarjeta.texto)
                .font(.body)
                .foregroundStyle(Paleta.texto(scheme))
                .fixedSize(horizontal: false, vertical: true)
            if let destino = tarjeta.destino, let titulo = tarjeta.tituloDestino {
                if let ruta = destino.ruta {
                    NavigationLink(value: ruta) {
                        Text(titulo).font(.body.weight(.semibold)).frame(minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                } else if case .koFi(let cual) = destino {
                    BotonKoFi(titulo: titulo, cual: cual, estilo: .principal)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Paleta.superficie(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Paleta.borde(scheme)))
    }
}

struct MetaCerebroVista: View {
    @Environment(ModeloApp.self) private var modelo
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch modelo.meta {
            case .valor(let meta, _):
                Text(meta.texto)
                    .font(.system(.title, design: .serif).weight(.bold))
                    .foregroundStyle(Paleta.texto(scheme))
                    .accessibilityLabel("Cerebro para Lufy")
                    .accessibilityValue(meta.valorAccesible)
                ProgressView(value: meta.fraccion)
                    .tint(Paleta.oro)
                    .accessibilityHidden(true)
                Text("Actualizado: \(meta.actualizado)")
                    .font(.footnote)
                    .foregroundStyle(Paleta.suave(scheme))
            case .fallo(let mensaje):
                Text(mensaje)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Paleta.texto(scheme))
                    .accessibilityLabel(mensaje)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Paleta.superficie(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .leading) { Rectangle().fill(Paleta.oro).frame(width: 4) }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ArchivoVista: View {
    let archivo: ArchivoPublico
    let titulo: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TituloSeccion(texto: titulo)
            Text(archivo.introduccion)
                .foregroundStyle(Paleta.texto(scheme))
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(Array(archivo.cifras.enumerated()), id: \.offset) { _, cifra in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(cifra.meta)
                            .font(.caption)
                            .foregroundStyle(Paleta.suave(scheme))
                        Text(cifra.valor)
                            .font(.system(.title, design: .serif).weight(.bold))
                            .foregroundStyle(Paleta.texto(scheme))
                        Text(cifra.etiqueta)
                            .foregroundStyle(Paleta.texto(scheme))
                        FuenteLinea(fuente: cifra.fuente)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Paleta.superficie(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .leading) { Rectangle().fill(Paleta.oro).frame(width: 4) }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            Text(archivo.notaSinCopia)
                .font(.footnote)
                .foregroundStyle(Paleta.suave(scheme))
                .fixedSize(horizontal: false, vertical: true)
            GraficoVista(grafico: Grafico(
                titulo: archivo.graficoTitulo,
                nota: archivo.graficoNota,
                leyenda: nil,
                barras: archivo.grafico
            ))
        }
    }
}

struct HiloResumen: View {
    let hilo: Hilo
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(hilo.fecha) · \(hilo.tema)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Paleta.suave(scheme))
            Text(hilo.titulo)
                .font(.system(.title3, design: .serif).weight(.bold))
                .foregroundStyle(Paleta.texto(scheme))
                .fixedSize(horizontal: false, vertical: true)
            Text(hilo.resumen)
                .foregroundStyle(Paleta.texto(scheme))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(hilo.destacados.enumerated()), id: \.offset) { _, cifra in
                VStack(alignment: .leading, spacing: 4) {
                    if let sello = cifra.sello { SelloVista(sello: sello) }
                    Text(cifra.valor).font(.system(.title3, design: .serif).weight(.bold))
                    Text(cifra.detalle).font(.subheadline)
                }
            }
            Text(hilo.fuente.linea)
                .font(.footnote)
                .foregroundStyle(Paleta.suave(scheme))
            Text("Abrir el hilo")
                .font(.body.weight(.semibold))
                .frame(minHeight: 44, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Paleta.superficie(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Paleta.borde(scheme)))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Abre el hilo en Lufy.")
    }
}

enum Portapapeles {
    static func copiar(_ texto: String) {
        #if os(iOS)
        UIPasteboard.general.string = texto
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(texto, forType: .string)
        #endif
    }
}
