import SwiftUI
import LufyCore

enum EnlacesVista {
    static func pagina(_ catalogo: Catalogo, ruta: String) -> URL? {
        guard let url = PoliticaEnlaces.urlLufy(origen: catalogo.origen, ruta: ruta),
              let raiz = URL(string: PoliticaEnlaces.normalizarOrigen(catalogo.origen) ?? catalogo.origen),
              PoliticaEnlaces.puedeAbrir(url, origen: raiz, mostrarKoFi: false) else {
            return nil
        }
        return url
    }

    static func kofi(_ catalogo: Catalogo, token: String) -> URL? {
        guard Configuracion.mostrarEnlacesKoFi else { return nil }
        let texto: String
        switch token {
        case "kofi": texto = catalogo.enlaces.kofi
        case "libro": texto = catalogo.enlaces.libro
        case "muestra": texto = catalogo.enlaces.muestra
        default: return nil
        }
        guard let url = PoliticaEnlaces.urlKoFi(texto),
              let raiz = URL(string: PoliticaEnlaces.normalizarOrigen(catalogo.origen) ?? catalogo.origen),
              PoliticaEnlaces.puedeAbrir(url, origen: raiz, mostrarKoFi: true) else {
            return nil
        }
        return url
    }

    static func titulo(_ token: String) -> String {
        switch token {
        case "kofi": "Abrir Ko-fi"
        case "libro": "Comprar el libro"
        case "muestra": "Abrir la muestra"
        default: "Abrir"
        }
    }
}

struct Balanza: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 64
        let sy = rect.height / 64
        func punto(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }
        var camino = Path()
        camino.move(to: punto(32, 12))
        camino.addLine(to: punto(32, 38))
        camino.move(to: punto(20, 46))
        camino.addLine(to: punto(44, 46))
        camino.move(to: punto(16, 20))
        camino.addLine(to: punto(48, 20))
        camino.move(to: punto(16, 20))
        camino.addLine(to: punto(10, 34))
        camino.addLine(to: punto(22, 34))
        camino.closeSubpath()
        camino.move(to: punto(48, 20))
        camino.addLine(to: punto(42, 34))
        camino.addLine(to: punto(54, 34))
        camino.closeSubpath()
        return camino
    }
}

struct MarcaLufy: View {
    var sobreVino: Bool = true

    var body: some View {
        HStack(spacing: 10) {
            Balanza()
                .stroke(Color("Oro"), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            HStack(spacing: 0) {
                Text("LUF")
                Text("Y").foregroundStyle(Color("Oro"))
            }
            .font(.system(.title3, design: .serif).weight(.semibold))
            .foregroundStyle(sobreVino ? Color("TextoSobreVino") : Color("Texto"))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lufy")
    }
}

struct Cabecera: View {
    let sobre: String
    let titulo: String
    var entradilla: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MarcaLufy()
            Text(sobre)
                .font(.subheadline)
                .foregroundStyle(Color("OroSuave"))
            Text(titulo)
                .font(.system(.largeTitle, design: .serif))
                .foregroundStyle(Color("TextoSobreVino"))
                .accessibilityAddTraits(.isHeader)
            if let entradilla, !entradilla.isEmpty {
                Text(entradilla)
                    .font(.body)
                    .foregroundStyle(Color("TextoSobreVino"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color("Vino"))
    }
}

struct ColumnaLectura<Contenido: View>: View {
    @ViewBuilder var contenido: () -> Contenido

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                contenido()
            }
            .padding(.bottom, 36)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color("Fondo").ignoresSafeArea())
        .modifier(BarraActualizar())
    }
}

struct BarraActualizar: ViewModifier {
    @Environment(CatalogoTienda.self) private var tienda

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .automatic) {
                if tienda.actualizando {
                    ProgressView()
                        .accessibilityLabel("Actualizando el contenido")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await tienda.actualizar() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Actualizar contenido")
            }
        }
    }
}

struct TarjetaFondo: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color("Tarjeta"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color("Borde"), lineWidth: 1)
            )
    }
}

extension View {
    func tarjeta() -> some View { modifier(TarjetaFondo()) }
}

struct PastillaSello: View {
    let sello: Sello

    var body: some View {
        Text(sello.rawValue)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color("TextoSobreOro"))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color("Oro"), in: Capsule())
            .accessibilityLabel("Sello \(sello.rawValue)")
    }
}

struct MarcaOCR: View {
    var body: some View {
        Text("OCR")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color("Suave"))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .overlay(Capsule().stroke(Color("Borde"), lineWidth: 1))
            .accessibilityLabel("Marca de lectura OCR. No es un sello de hallazgo.")
    }
}

struct NotaLecturaVista: View {
    let nota: NotaLectura

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let sello = nota.sello {
                PastillaSello(sello: sello)
            }
            if nota.ocr {
                MarcaOCR()
            }
            Text(nota.texto)
                .font(.subheadline)
                .foregroundStyle(Color("Texto"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct FuenteVista: View {
    let fuente: Fuente
    let origen: String
    @State private var mostrarCopia = false

    var body: some View {
        if fuente.archivo != nil {
            Button {
                mostrarCopia = true
            } label: {
                Text(fuente.linea)
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color("Enlace"))
            .accessibilityLabel("Fuente: \(fuente.institucion), \(fuente.documento), \(fuente.fecha). Abrir la copia archivada en Lufy.")
            .sheet(isPresented: $mostrarCopia) {
                if let copia = fuente.archivo {
                    HojaArchivo(fuente: fuente, copia: copia, origen: origen)
                }
            }
        } else {
            Text(fuente.linea)
                .font(.footnote)
                .foregroundStyle(Color("Suave"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Fuente, sin enlace: \(fuente.institucion). \(fuente.documento). \(fuente.fecha).")
        }
    }
}

struct HojaArchivo: View {
    let fuente: Fuente
    let copia: CopiaArchivada
    let origen: String
    @Environment(\.dismiss) private var cerrar
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(fuente.linea)
                    .font(.body)
                LabeledContent("Institución", value: fuente.institucion)
                LabeledContent("Documento", value: fuente.documento)
                LabeledContent("Fecha", value: fuente.fecha)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Huella SHA-256")
                        .font(.subheadline.weight(.semibold))
                    Text(copia.sha256)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .accessibilityLabel("Huella SHA-256 \(copia.sha256)")
                }
                LabeledContent("Archivado", value: copia.archivado)
                if let url = PoliticaEnlaces.urlLufy(origen: origen, ruta: copia.ruta) {
                    Button("Abrir la copia de Lufy") { openURL(url) }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("Vino"))
                        .frame(minHeight: 44)
                        .accessibilityHint("Abre el documento alojado en Lufy")
                }
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color("Fondo"))
            .navigationTitle("Copia archivada")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { cerrar() }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }
}

struct NotaSinCopia: View {
    let texto: String

    var body: some View {
        Text(texto)
            .font(.footnote)
            .foregroundStyle(Color("Suave"))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CifraTarjeta: View {
    let cifra: Cifra
    let origen: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let sello = cifra.sello { PastillaSello(sello: sello) }
                if cifra.ocr { MarcaOCR() }
            }
            Text(cifra.valor)
                .font(.system(.title2, design: .serif))
                .foregroundStyle(Color("Texto"))
                .accessibilityLabel(cifra.valor)
            Text(cifra.detalle)
                .font(.subheadline)
                .foregroundStyle(Color("Texto"))
            if let meta = cifra.meta, !meta.isEmpty {
                Text(meta)
                    .font(.caption)
                    .foregroundStyle(Color("Suave"))
            }
            FuenteVista(fuente: cifra.fuente, origen: origen)
        }
        .tarjeta()
    }
}

struct BarraMetaVista: View {
    let meta: MetaRecaudacion
    @Environment(\.accessibilityReduceMotion) private var reducir

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(meta.textoCifra)
                .font(.headline)
                .foregroundStyle(Color("Texto"))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color("Papel2"))
                    Capsule()
                        .fill(Color("Oro"))
                        .frame(width: max(0, geo.size.width * meta.fraccion))
                }
            }
            .frame(height: 10)
            .accessibilityHidden(true)
            Text(meta.textoFecha)
                .font(.caption)
                .foregroundStyle(Color("Suave"))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(meta.textoCifra). \(meta.textoFecha)")
        .animation(reducir ? nil : .easeOut(duration: 0.35), value: meta.fraccion)
    }
}

func textoConMeta(_ plantilla: String, meta: MetaRecaudacion?) -> String {
    let cifra = meta?.textoCifra ?? "la meta publicada en Lufy"
    return plantilla
        .replacingOccurrences(of: "{{meta}} USD", with: cifra)
        .replacingOccurrences(of: "{{meta}}", with: cifra)
}

struct BotonToken: View {
    let token: String
    let catalogo: Catalogo
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let url = EnlacesVista.kofi(catalogo, token: token) {
            Button(EnlacesVista.titulo(token)) { openURL(url) }
                .buttonStyle(.borderedProminent)
                .tint(Color("Vino"))
                .frame(minHeight: 44)
                .accessibilityHint("Sale de Lufy hacia Ko-fi")
        }
    }
}

struct BotonesForma: View {
    let forma: FormaApoyo
    let catalogo: Catalogo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let token = forma.boton {
                BotonToken(token: token, catalogo: catalogo)
            }
            if let token = forma.botonSecundario {
                BotonToken(token: token, catalogo: catalogo)
            }
        }
    }
}

struct CompartirLufy: View {
    let url: URL
    let mensaje: String

    var body: some View {
        ShareLink(item: url, subject: Text("Lufy"), message: Text(mensaje)) {
            Label("Compartir", systemImage: "square.and.arrow.up")
        }
        .frame(minHeight: 44)
        .accessibilityLabel("Compartir la página de Lufy")
    }
}

struct AvisoPagoApagado: View {
    var body: some View {
        if !Configuracion.mostrarEnlacesKoFi {
            Text("Esta compilación no incluye enlaces de pago.")
                .font(.footnote)
                .foregroundStyle(Color("Suave"))
        }
    }
}

struct EstadoCopia: View {
    let origen: OrigenCarga?

    var body: some View {
        if origen != nil {
            Text(texto)
                .font(.caption)
                .foregroundStyle(Color("Suave"))
                .accessibilityLabel(texto)
        }
    }

    private var texto: String {
        switch origen {
        case .red: "Leído desde Lufy."
        case .cache: "Copia guardada en este dispositivo."
        case .paquete: "Copia incluida en la app."
        case nil: ""
        }
    }
}

struct VacioLufy: View {
    @Environment(CatalogoTienda.self) private var tienda

    var body: some View {
        VStack(spacing: 16) {
            MarcaLufy(sobreVino: false)
            Text("No se pudo abrir el contenido de Lufy.")
                .font(.title3)
                .multilineTextAlignment(.center)
            Button("Reintentar") {
                Task { await tienda.actualizar() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("Vino"))
            .frame(minHeight: 44)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Fondo"))
    }
}

struct ContenidoListo<Contenido: View>: View {
    @Environment(CatalogoTienda.self) private var tienda
    @ViewBuilder var contenido: (Catalogo) -> Contenido

    var body: some View {
        if let catalogo = tienda.catalogo {
            contenido(catalogo)
        } else {
            VacioLufy()
        }
    }
}

enum RecoleccionFuentes {
    static func de(bloque: Bloque) -> [Fuente] {
        switch bloque {
        case .prosa(let prosa):
            prosa.fuente.map { [$0] } ?? []
        case .lista(let lista):
            lista.fuente.map { [$0] } ?? []
        case .grafico(let grafico):
            grafico.fuente.map { [$0] } ?? []
        case .tabla(let tabla):
            tabla.fuente.map { [$0] } ?? []
        case .tiempo(let tiempo):
            tiempo.fuente.map { [$0] } ?? []
        case .documentos(let documentos):
            documentos.items.map(\.fuente)
        case .aviso, .columnas, .ficha, .glosario, .cambios, .desconocido:
            []
        }
    }

    static func todasFaltan(_ fuentes: [Fuente]) -> Bool {
        !fuentes.isEmpty && fuentes.allSatisfy { $0.archivo == nil }
    }
}
