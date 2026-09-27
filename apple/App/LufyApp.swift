import SwiftUI

@main
struct LufyApp: App {
    @State private var tienda = CatalogoTienda()
    @State private var feed = FeedTienda()
    @State private var pagos = TiendaPagos()
    @State private var seguimientos = SeguimientosTienda()

    var body: some Scene {
        WindowGroup {
            RaizLufy()
                .environment(tienda)
                .environment(feed)
                .environment(pagos)
                .environment(seguimientos)
        }
        #if os(macOS)
        .defaultSize(width: 1080, height: 760)
        #endif
    }
}

enum Seccion: String, CaseIterable, Identifiable {
    case inicio
    case datos
    case asamblea
    case libro
    case apoya
    case historia
    case privacidad
    case pago
    case avisos

    static var menu: [Seccion] {
        allCases.filter { item in
            switch item {
            case .pago, .avisos:
                Configuracion.capaDePagoActiva
            default:
                true
            }
        }
    }

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .inicio: "Inicio"
        case .datos: "Datos"
        case .asamblea: "Asamblea"
        case .libro: "Libro"
        case .apoya: "Apoya"
        case .historia: "Historia"
        case .privacidad: "Privacidad"
        case .pago: "Acceso anticipado"
        case .avisos: "Avisos"
        }
    }

    var simbolo: String {
        switch self {
        case .inicio: "house"
        case .datos: "chart.bar"
        case .asamblea: "building.columns"
        case .libro: "book.closed"
        case .apoya: "heart"
        case .historia: "clock"
        case .privacidad: "hand.raised"
        case .pago: "creditcard"
        case .avisos: "bell"
        }
    }
}

struct RaizLufy: View {
    @Environment(CatalogoTienda.self) private var tienda
    @Environment(FeedTienda.self) private var feed
    @Environment(TiendaPagos.self) private var pagos
    @Environment(SeguimientosTienda.self) private var seguimientos

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
        .task {
            guard let origen = tienda.catalogo?.origen else { return }
            await feed.actualizarSiToca(origen: origen)
        }
        .task(id: "\(feed.actualizado ?? "")|\(pagos.suscrito)") {
            await pagos.preparar(dossiers: feed.dossiers)
            seguimientos.registrar(
                piezas: feed.piezas,
                puedeAvisar: Configuracion.capaDePagoActiva && pagos.suscrito
            )
        }
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
            NavigationStack { PantallaAsamblea() }
                .tabItem { Label(Seccion.asamblea.titulo, systemImage: Seccion.asamblea.simbolo) }
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
            List(Seccion.menu, selection: $seccion) { item in
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
                case .asamblea: PantallaAsamblea()
                case .libro: PantallaLibro()
                case .apoya: PantallaApoyo()
                case .historia: PantallaHistoria()
                case .privacidad: PantallaPrivacidad()
                case .pago: PantallaPago()
                case .avisos: PantallaAvisos()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
