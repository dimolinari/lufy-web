import SwiftUI
import LufyCore

enum Paleta {
    static let vino = Color(red: 61 / 255, green: 24 / 255, blue: 32 / 255)
    static let vinoProfundo = Color(red: 42 / 255, green: 16 / 255, blue: 22 / 255)
    static let oro = Color(red: 212 / 255, green: 179 / 255, blue: 106 / 255)
    static let oroSuave = Color(red: 240 / 255, green: 212 / 255, blue: 138 / 255)
    static let tinta = Color(red: 26 / 255, green: 18 / 255, blue: 15 / 255)
    static let papel = Color(red: 243 / 255, green: 238 / 255, blue: 228 / 255)
    static let papel2 = Color(red: 231 / 255, green: 223 / 255, blue: 208 / 255)
    static let blanco = Color(red: 255 / 255, green: 253 / 255, blue: 248 / 255)
    static let enlace = Color(red: 106 / 255, green: 52 / 255, blue: 8 / 255)
    static let ok = Color(red: 12 / 255, green: 90 / 255, blue: 50 / 255)
    static let indicio = Color(red: 30 / 255, green: 63 / 255, blue: 104 / 255)
    static let abierto = Color(red: 122 / 255, green: 78 / 255, blue: 10 / 255)
    static let hipotesis = Color(red: 84 / 255, green: 58 / 255, blue: 104 / 255)

    static func fondo(_ scheme: ColorScheme) -> Color { scheme == .dark ? tinta : papel }
    static func superficie(_ scheme: ColorScheme) -> Color { scheme == .dark ? vinoProfundo : blanco }
    static func texto(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? papel : Color(red: 36 / 255, green: 25 / 255, blue: 16 / 255)
    }
    static func suave(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 217 / 255, green: 207 / 255, blue: 187 / 255) : Color(red: 92 / 255, green: 83 / 255, blue: 72 / 255)
    }
    static func borde(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.14) : Color(red: 221 / 255, green: 211 / 255, blue: 195 / 255)
    }
    static func pista(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.12) : papel2
    }
    static func saber(_ scheme: ColorScheme) -> Color { scheme == .dark ? vino : tinta }

    static func relleno(_ estilo: EstiloBarra, _ scheme: ColorScheme) -> Color {
        switch estilo {
        case .vino, .vinoRayado:
            return scheme == .dark ? Color(red: 0.86, green: 0.62, blue: 0.66) : vino
        case .oro, .oroRayado:
            return oro
        case .tinta, .punto:
            return scheme == .dark ? papel : tinta
        }
    }
}

struct MarcaBalanza: View {
    var body: some View {
        Canvas { contexto, size in
            let escala = min(size.width, size.height) / 32
            func punto(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * escala, y: y * escala)
            }
            var camino = Path()
            camino.move(to: punto(16, 5))
            camino.addLine(to: punto(16, 21))
            camino.move(to: punto(10, 25))
            camino.addLine(to: punto(22, 25))
            camino.move(to: punto(7, 9))
            camino.addLine(to: punto(25, 9))
            camino.move(to: punto(7, 9))
            camino.addLine(to: punto(3.8, 16))
            camino.addLine(to: punto(10.2, 16))
            camino.closeSubpath()
            camino.move(to: punto(25, 9))
            camino.addLine(to: punto(21.8, 16))
            camino.addLine(to: punto(28.2, 16))
            camino.closeSubpath()
            contexto.stroke(camino, with: .color(Paleta.oro), style: StrokeStyle(lineWidth: 1.7 * escala, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}

struct MarcaLufy: View {
    var compacta = false

    var body: some View {
        HStack(spacing: 8) {
            MarcaBalanza()
                .frame(width: compacta ? 22 : 28, height: compacta ? 22 : 28)
            HStack(spacing: 0) {
                Text("LUF")
                Text("Y").foregroundStyle(Paleta.oro)
            }
            .font(.system(compacta ? .title3 : .title2, design: .serif).weight(.bold))
            .tracking(3)
            .foregroundStyle(Paleta.papel)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lufy")
    }
}

struct SelloVista: View {
    let sello: Sello
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text(sello.rawValue)
            .font(.caption.weight(.heavy))
            .foregroundStyle(colorTexto)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colorFondo, in: Capsule())
            .overlay(Capsule().strokeBorder(colorTexto, lineWidth: 1))
            .accessibilityLabel(sello.descripcionAccesible)
    }

    private var colorTexto: Color {
        switch sello {
        case .confirmado: scheme == .dark ? Color(red: 0.72, green: 0.92, blue: 0.79) : Paleta.ok
        case .indicio: scheme == .dark ? Color(red: 0.77, green: 0.84, blue: 0.95) : Paleta.indicio
        case .abierto: scheme == .dark ? Paleta.oroSuave : Paleta.abierto
        case .hipotesis: scheme == .dark ? Color(red: 0.88, green: 0.82, blue: 0.94) : Paleta.hipotesis
        }
    }

    private var colorFondo: Color {
        switch sello {
        case .confirmado: scheme == .dark ? Color(red: 0.08, green: 0.22, blue: 0.14) : Color(red: 0.90, green: 0.96, blue: 0.93)
        case .indicio: scheme == .dark ? Color(red: 0.10, green: 0.16, blue: 0.27) : Color(red: 0.91, green: 0.93, blue: 0.96)
        case .abierto: scheme == .dark ? Color(red: 0.23, green: 0.17, blue: 0.07) : Color(red: 0.97, green: 0.94, blue: 0.86)
        case .hipotesis: scheme == .dark ? Color(red: 0.18, green: 0.13, blue: 0.22) : Color(red: 0.95, green: 0.93, blue: 0.96)
        }
    }
}

struct MarcaOCR: View {
    var body: some View {
        Text("OCR")
            .font(.caption.weight(.heavy))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(Paleta.abierto)
            .background(Paleta.oro.opacity(0.25), in: Capsule())
            .overlay(Capsule().strokeBorder(Paleta.abierto, lineWidth: 1))
            .accessibilityLabel("Leído con OCR y contrastado con la imagen.")
    }
}

struct EtiquetaBoton: View {
    var titulo: String
    var estilo: EstiloBoton
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text(titulo)
            .font(.body.weight(.bold))
            .multilineTextAlignment(.center)
            .foregroundStyle(colorTexto)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(fondo, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Paleta.oro, lineWidth: 2))
    }

    private var fondo: Color {
        switch estilo {
        case .principal: Paleta.oro
        case .secundario: .clear
        case .claro: .clear
        }
    }

    private var colorTexto: Color {
        switch estilo {
        case .principal: Paleta.tinta
        case .secundario: scheme == .dark ? Paleta.oroSuave : Paleta.enlace
        case .claro: Paleta.papel
        }
    }
}

struct TarjetaSuperficie<Contenido: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var contenido: Contenido

    var body: some View {
        contenido
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Paleta.superficie(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Paleta.borde(scheme), lineWidth: 1))
    }
}

struct TituloSeccion: View {
    var texto: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(texto)
                .font(.system(.title2, design: .serif).weight(.bold))
                .foregroundStyle(Paleta.texto(scheme))
                .fixedSize(horizontal: false, vertical: true)
            Rectangle()
                .fill(Paleta.oro)
                .frame(width: 52, height: 3)
                .accessibilityHidden(true)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

func textoRico(_ fuente: String) -> Text {
    let partes = TextoMarcado.fragmentos(fuente)
    guard !partes.isEmpty else { return Text(verbatim: fuente) }
    return partes.reduce(Text(verbatim: "")) { acumulado, parte in
        let pieza: Text = switch parte.estilo {
        case .normal: Text(verbatim: parte.texto)
        case .fuerte: Text(verbatim: parte.texto).bold()
        case .enfasis: Text(verbatim: parte.texto).italic()
        }
        return acumulado + pieza
    }
}

struct BarraLufy: ViewModifier {
    @Environment(ModeloApp.self) private var modelo
    var titulo: String

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { boton }
            .toolbarBackground(Paleta.vino, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        #else
        content
            .navigationTitle(titulo)
            .toolbar { boton }
        #endif
    }

    @ToolbarContentBuilder
    private var boton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await modelo.actualizar() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(modelo.actualizando)
            .accessibilityLabel("Actualizar contenido")
        }
    }
}

extension View {
    func barraLufy(_ titulo: String) -> some View {
        modifier(BarraLufy(titulo: titulo))
    }

    func fondoLufy() -> some View {
        modifier(FondoLufy())
    }
}

struct FondoLufy: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background(Paleta.fondo(scheme).ignoresSafeArea())
    }
}

struct MarcoLectura<Contenido: View>: View {
    @ViewBuilder var contenido: Contenido

    var body: some View {
        contenido
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity)
    }
}

struct PieLufy: View {
    @Environment(ModeloApp.self) private var modelo
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if modelo.actualizando {
                Text("Buscando la versión publicada…")
            }
            Text(modelo.lineaOrigen)
            if !Ajustes.muestraEnlacesKoFi {
                Text("En esta versión los enlaces a Ko-fi están desactivados.")
            }
            Text("© 2026 Lufy. Sin cuentas, sin analítica y sin rastreadores.")
        }
        .font(.footnote)
        .foregroundStyle(Paleta.suave(scheme))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 28)
    }
}

struct VistaVacia: View {
    var titulo: String
    var detalle: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titulo)
                .font(.system(.title2, design: .serif).weight(.bold))
            Text(detalle)
                .foregroundStyle(Paleta.suave(scheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
        .fondoLufy()
    }
}
