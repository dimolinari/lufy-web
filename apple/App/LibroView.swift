import LufyCore
import SwiftUI

struct LibroView: View {
    @Environment(ModeloApp.self) private var modelo
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let libro = modelo.contenido?.libro {
            contenido(libro)
        } else {
            VistaVacia(titulo: "El libro no está en el índice", detalle: "Actualiza el contenido cuando tengas conexión.")
        }
    }

    private func contenido(_ libro: Libro) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                MarcoLectura {
                    VStack(alignment: .leading, spacing: 28) {
                        HStack {
                            Spacer(minLength: 0)
                            PortadaLibro(libro: libro)
                            Spacer(minLength: 0)
                        }
                        Text(libro.titulo)
                            .font(.system(.largeTitle, design: .serif).weight(.bold))
                            .foregroundStyle(Paleta.texto(scheme))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(libro.subtitulo)
                            .font(.title3)
                            .foregroundStyle(Paleta.suave(scheme))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(libro.autor)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Paleta.texto(scheme))
                        Text(libro.meta)
                            .font(.footnote)
                            .foregroundStyle(Paleta.suave(scheme))
                        Text(libro.entradilla)
                            .font(.body)
                            .foregroundStyle(Paleta.texto(scheme))
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(Array(libro.parrafos.enumerated()), id: \.offset) { _, parrafo in
                            Text(parrafo)
                                .foregroundStyle(Paleta.texto(scheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        compra(libro)
                        TituloSeccion(texto: "La historia")
                        ForEach(Array(libro.historia.enumerated()), id: \.offset) { _, parrafo in
                            Text(parrafo)
                                .foregroundStyle(Paleta.texto(scheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(libro.momentos.enumerated()), id: \.offset) { _, momento in
                                Button {
                                    proxy.scrollTo(momento.ancla, anchor: .top)
                                } label: {
                                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                                        Text(momento.fecha)
                                            .font(.subheadline.weight(.bold))
                                            .frame(minWidth: 88, alignment: .leading)
                                        Text(momento.texto)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .frame(minHeight: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(momento.fecha). \(momento.texto). Ir al capítulo.")
                            }
                        }
                        Text(libro.antes)
                            .foregroundStyle(Paleta.suave(scheme))
                            .fixedSize(horizontal: false, vertical: true)
                        TituloSeccion(texto: "Contenido")
                        ForEach(libro.capitulos) { capitulo in
                            CapituloFila(capitulo: capitulo)
                                .id(capitulo.ancla)
                        }
                        TituloSeccion(texto: "Cómo está hecho")
                        lista(libro.comoEstaHecho)
                        Text(libro.avisoRedaccion)
                            .font(.footnote)
                            .foregroundStyle(Paleta.suave(scheme))
                            .fixedSize(horizontal: false, vertical: true)
                        TituloSeccion(texto: "Para quién es")
                        lista(libro.paraQuien)
                        TituloSeccion(texto: "Esta edición")
                        lista(libro.edicion)
                        muestra(libro)
                        PieLufy()
                    }
                }
            }
        }
        .fondoLufy()
        .barraLufy("Libro")
        .toolbar { compartir(libroRuta: modelo.contenido?.libro.ruta) }
    }

    @ViewBuilder
    private func compra(_ libro: Libro) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(libro.pagaLoQueQuieras)
                .foregroundStyle(Paleta.texto(scheme))
                .fixedSize(horizontal: false, vertical: true)
            Text("Lo sugerido son \(libro.sugeridoUSD) USD.")
                .font(.subheadline.weight(.semibold))
            if Ajustes.muestraEnlacesKoFi {
                BotonKoFi(titulo: "Conseguir el libro en Ko-fi", cual: .libro, estilo: .principal)
            } else {
                Text("En esta versión el enlace de compra está desactivado.")
                    .font(.footnote)
                    .foregroundStyle(Paleta.suave(scheme))
            }
            ForEach(Array(libro.pasos.enumerated()), id: \.offset) { _, paso in
                Text("· \(paso)")
                    .foregroundStyle(Paleta.suave(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func muestra(_ libro: Libro) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TituloSeccion(texto: "Muestra pública")
            Text(libro.muestra.descripcion)
                .foregroundStyle(Paleta.texto(scheme))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(libro.muestra.incluye.enumerated()), id: \.offset) { _, item in
                Text(item)
                    .font(.body.weight(.semibold))
            }
            Text("La app no incluye el texto completo del libro.")
                .font(.footnote)
                .foregroundStyle(Paleta.suave(scheme))
            if Ajustes.muestraEnlacesKoFi {
                BotonKoFi(titulo: "Leer la muestra en Ko-fi", cual: .muestra, estilo: .secundario)
            } else {
                Text("En esta versión el enlace de la muestra está desactivado.")
                    .font(.footnote)
                    .foregroundStyle(Paleta.suave(scheme))
            }
        }
        .id("muestra")
    }

    private func lista(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text(item)
                    .foregroundStyle(Paleta.texto(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ToolbarContentBuilder
    private func compartir(libroRuta: String?) -> some ToolbarContent {
        if let libroRuta, let url = OrigenPublico.url(libroRuta) {
            ToolbarItem(placement: .automatic) {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Compartir la página del libro en Lufy")
            }
        }
    }
}

struct PortadaLibro: View {
    let libro: Libro

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Paleta.vino)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Paleta.oro, lineWidth: 2)
                .padding(8)
            VStack(spacing: 14) {
                MarcaBalanza()
                    .frame(width: 72, height: 72)
                Text("LUFY")
                    .font(.caption.weight(.heavy))
                    .tracking(4)
                    .foregroundStyle(Paleta.oro)
                Text(libro.titulo)
                    .font(.system(.title2, design: .serif).weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Paleta.papel)
                Text("Ecuador 1972–2023")
                    .font(.subheadline)
                    .foregroundStyle(Paleta.oroSuave)
            }
            .padding(28)
        }
        .frame(maxWidth: 280)
        .aspectRatio(0.68, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Portada. \(libro.titulo). \(libro.subtitulo). \(libro.autor).")
    }
}

struct CapituloFila: View {
    let capitulo: Capitulo
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(capitulo.numero)")
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .foregroundStyle(Paleta.abierto)
                    .frame(width: 28, alignment: .leading)
                Text(capitulo.titulo)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Paleta.texto(scheme))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if capitulo.enMuestra {
                    Text("En la muestra")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Paleta.abierto)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Paleta.oro.opacity(0.25), in: Capsule())
                }
            }
            Text(capitulo.periodo)
                .font(.caption)
                .foregroundStyle(Paleta.suave(scheme))
                .fixedSize(horizontal: false, vertical: true)
            Text(capitulo.resumen)
                .font(.subheadline)
                .foregroundStyle(Paleta.texto(scheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}
