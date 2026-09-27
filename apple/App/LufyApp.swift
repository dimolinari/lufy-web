import SwiftUI

@main
struct LufyApp: App {
    @State private var tienda = CatalogoTienda()

    var body: some Scene {
        WindowGroup {
            RaizLufy()
                .environment(tienda)
        }
        #if os(macOS)
        .defaultSize(width: 1080, height: 760)
        #endif
    }
}

enum Seccion: String, CaseIterable, Identifiable {
    case inicio
    case datos
    case libro
    case apoya
    case historia
    case privacidad

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .inicio: "Inicio"
        case .datos: "Datos"
        case .libro: "Libro"
        case .apoya: "Apoya"
        case .historia: "Historia"
        case .privacidad: "Privacidad"
        }
    }

    var simbolo: String {
        switch self {
        case .inicio: "house"
        case .datos: "chart.bar"
        case .libro: "book.closed"
        case .apoya: "heart"
        case .historia: "clock"
        case .privacidad: "hand.raised"
        }
    }
}

struct RaizLufy: View {
    @Environment(CatalogoTienda.self) private var tienda

    var body: some View {
        Group {
            #if os(iOS)
            RaizAdaptativa()
            #else
            RaizDividida()
            #endif
        }
        .environment(\.locale, Locale(identifier: "es"))
        .tint(Color("Vino"))
        .task { await tienda.actualizar() }
    }
}

#if os(iOS)
private struct RaizAdaptativa: View {
    @Environment(\.horizontalSizeClass) private var ancho

    var body: some View {
        if ancho == .compact {
            RaizPestanas()
        } else {
            RaizDividida()
        }
    }
}

private struct RaizPestanas: View {
    var body: some View {
        TabView {
            NavigationStack { PantallaInicio() }
                .tabItem { Label(Seccion.inicio.titulo, systemImage: Seccion.inicio.simbolo) }
            NavigationStack { PantallaDatos() }
                .tabItem { Label(Seccion.datos.titulo, systemImage: Seccion.datos.simbolo) }
            NavigationStack { PantallaLibro() }
                .tabItem { Label(Seccion.libro.titulo, systemImage: Seccion.libro.simbolo) }
            NavigationStack { PantallaApoyo() }
                .tabItem { Label(Seccion.apoya.titulo, systemImage: Seccion.apoya.simbolo) }
            NavigationStack { PantallaMas() }
                .tabItem { Label("Más", systemImage: "ellipsis") }
        }
    }
}
#endif

struct RaizDividida: View {
    @State private var seccion: Seccion? = .inicio

    var body: some View {
        NavigationSplitView {
            List(Seccion.allCases, selection: $seccion) { item in
                Label(item.titulo, systemImage: item.simbolo)
                    .tag(Optional(item))
            }
            .navigationTitle("Lufy")
            .listStyle(.sidebar)
        } detail: {
            NavigationStack {
                switch seccion ?? .inicio {
                case .inicio: PantallaInicio()
                case .datos: PantallaDatos()
                case .libro: PantallaLibro()
                case .apoya: PantallaApoyo()
                case .historia: PantallaHistoria()
                case .privacidad: PantallaPrivacidad()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
