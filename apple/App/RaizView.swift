import LufyCore
import SwiftUI

enum SeccionRaiz: String, CaseIterable, Identifiable {
    case inicio
    case datos
    case libro
    case apoyo
    case mas

    var id: SeccionRaiz { self }

    var titulo: String {
        switch self {
        case .inicio: "Inicio"
        case .datos: "Datos"
        case .libro: "Libro"
        case .apoyo: "Apoya"
        case .mas: "Más"
        }
    }

    var simbolo: String {
        switch self {
        case .inicio: "house"
        case .datos: "text.magnifyingglass"
        case .libro: "book.closed"
        case .apoyo: "heart"
        case .mas: "ellipsis"
        }
    }
}

struct ReferenciaArchivo: Hashable {
    var institucion: String
    var documento: String
    var fecha: String
    var ruta: String
    var sha256: String
    var archivado: String
}

enum Ruta: Hashable {
    case hilo(String)
    case libro
    case apoyo
    case historia
    case privacidad
    case correcciones
    case datos
    case archivo(ReferenciaArchivo)
    case adjunto(String)
}

extension DestinoApp {
    var ruta: Ruta? {
        switch self {
        case .inicio: nil
        case .apoyo: .apoyo
        case .libro: .libro
        case .datos: .datos
        case .historia: .historia
        case .privacidad: .privacidad
        case .correcciones: .correcciones
        case .hilo(let id): .hilo(id)
        case .koFi: nil
        }
    }
}

extension Fuente {
    var referencia: ReferenciaArchivo? {
        guard let archivo, PoliticaEnlaces.urlLufy(ruta: archivo.ruta) != nil else { return nil }
        return ReferenciaArchivo(
            institucion: institucion,
            documento: documento,
            fecha: fecha,
            ruta: archivo.ruta,
            sha256: archivo.sha256,
            archivado: archivo.archivado
        )
    }
}

struct RaizView: View {
    @Environment(ModeloApp.self) private var modelo
    @Environment(\.horizontalSizeClass) private var tamano
    @Environment(\.colorScheme) private var scheme
    @State private var seccion: SeccionRaiz = .inicio

    private var seleccionLista: Binding<SeccionRaiz?> {
        Binding(
            get: { seccion },
            set: { if let nueva = $0 { seccion = nueva } }
        )
    }

    var body: some View {
        Group {
            if modelo.contenido == nil {
                VistaVacia(
                    titulo: "Lufy no puede abrir el archivo",
                    detalle: modelo.fallo ?? "Actualiza cuando tengas conexión."
                )
                .safeAreaInset(edge: .bottom) {
                    Button("Reintentar") { Task { await modelo.actualizar() } }
                        .buttonStyle(.borderedProminent)
                        .padding()
                }
            } else if tamano == .compact {
                tabs
            } else {
                columnas
            }
        }
        .tint(scheme == .dark ? Paleta.oroSuave : Paleta.enlace)
        .task { await modelo.actualizar() }
    }

    private var tabs: some View {
        TabView(selection: $seccion) {
            ForEach(SeccionRaiz.allCases) { item in
                PilaLufy { raiz(item) }
                    .tabItem { Label(item.titulo, systemImage: item.simbolo) }
                    .tag(item)
            }
        }
    }

    private var columnas: some View {
        NavigationSplitView {
            List(SeccionRaiz.allCases, selection: seleccionLista) { item in
                Label(item.titulo, systemImage: item.simbolo)
            }
            .navigationTitle("Lufy")
            .safeAreaInset(edge: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    MarcaLufy()
                    Text("Datos públicos del Ecuador")
                        .font(.caption)
                        .foregroundStyle(Paleta.papel.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Paleta.vino)
            }
        } detail: {
            PilaLufy { raiz(seccion) }
                .id(seccion)
        }
    }

    @ViewBuilder
    private func raiz(_ item: SeccionRaiz) -> some View {
        switch item {
        case .inicio:
            if let pagina = modelo.contenido?.inicio {
                PaginaView(pagina: pagina)
            }
        case .datos:
            if let pagina = modelo.contenido?.datos {
                PaginaView(pagina: pagina)
            }
        case .libro:
            LibroView()
        case .apoyo:
            if let pagina = modelo.contenido?.apoyo {
                PaginaView(pagina: pagina)
            }
        case .mas:
            MasView()
        }
    }
}

struct PilaLufy<Contenido: View>: View {
    @ViewBuilder var contenido: () -> Contenido

    var body: some View {
        NavigationStack {
            contenido()
                .navigationDestination(for: Ruta.self) { DestinoVista(ruta: $0) }
        }
    }
}

struct DestinoVista: View {
    let ruta: Ruta
    @Environment(ModeloApp.self) private var modelo

    var body: some View {
        switch ruta {
        case .hilo(let id):
            if let hilo = modelo.contenido?.hilos.first(where: { $0.id == id }) {
                HiloView(hilo: hilo)
            } else {
                VistaVacia(titulo: "Ese hilo no está en el índice", detalle: "Actualiza el contenido cuando tengas conexión.")
            }
        case .libro:
            LibroView()
        case .apoyo:
            if let pagina = modelo.contenido?.apoyo { PaginaView(pagina: pagina) }
        case .historia:
            if let pagina = modelo.contenido?.historia { PaginaView(pagina: pagina) }
        case .privacidad:
            if let pagina = modelo.contenido?.privacidad { PaginaView(pagina: pagina) }
        case .correcciones:
            if let pagina = modelo.contenido?.historia { PaginaView(pagina: pagina, ancla: "correcciones") }
        case .datos:
            if let pagina = modelo.contenido?.datos { PaginaView(pagina: pagina) }
        case .archivo(let referencia):
            VisorArchivo(referencia: referencia)
        case .adjunto(let id):
            VisorAdjunto(hiloID: id)
        }
    }
}

struct MasView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            MarcoLectura {
                VStack(alignment: .leading, spacing: 16) {
                    Text("El proyecto")
                        .font(.system(.largeTitle, design: .serif).weight(.bold))
                        .foregroundStyle(Paleta.texto(scheme))
                        .accessibilityAddTraits(.isHeader)
                    Text("Lufy publica datos públicos del Ecuador, con fuente, y un libro. El contenido principal es gratis.")
                        .foregroundStyle(Paleta.suave(scheme))
                    enlace("Nuestra historia", .historia)
                    enlace("Aviso de privacidad", .privacidad)
                    enlace("Correcciones", .correcciones)
                    enlace("Apoya a Lufy", .apoyo)
                    PieLufy()
                }
            }
        }
        .fondoLufy()
        .barraLufy("Más")
    }

    private func enlace(_ titulo: String, _ ruta: Ruta) -> some View {
        NavigationLink(value: ruta) {
            HStack {
                Text(titulo)
                    .font(.body.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }
}
