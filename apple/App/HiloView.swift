import LufyCore
import SwiftUI

struct HiloView: View {
    let hilo: Hilo
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            MarcoLectura {
                VStack(alignment: .leading, spacing: 22) {
                    Text(hilo.tema)
                        .font(.caption.weight(.heavy))
                        .tracking(1.1)
                        .textCase(.uppercase)
                        .foregroundStyle(Paleta.abierto)
                    Text(hilo.titulo)
                        .font(.system(.largeTitle, design: .serif).weight(.bold))
                        .foregroundStyle(Paleta.texto(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(hilo.fecha)
                        .font(.subheadline)
                        .foregroundStyle(Paleta.suave(scheme))
                    Text(hilo.entradilla)
                        .font(.title3)
                        .foregroundStyle(Paleta.texto(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(hilo.destacados.enumerated()), id: \.offset) { _, cifra in
                            CifraTarjeta(cifra: cifra)
                        }
                    }
                    FuenteLinea(fuente: hilo.fuente)
                    ForEach(hilo.secciones) { seccion in
                        SeccionVista(seccion: seccion)
                    }
                    if hilo.adjunto != nil {
                        NavigationLink(value: Ruta.adjunto(hilo.id)) {
                            EtiquetaBoton(titulo: hilo.adjunto?.titulo ?? "Abrir el archivo de Lufy", estilo: .secundario)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Abre el archivo publicado por Lufy. No es un sitio oficial.")
                    }
                    PieLufy()
                }
            }
        }
        .fondoLufy()
        .barraLufy(hilo.tema)
        .toolbar { compartir }
    }

    @ToolbarContentBuilder
    private var compartir: some ToolbarContent {
        if let url = OrigenPublico.url(hilo.ruta) {
            ToolbarItem(placement: .automatic) {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Compartir la página de Lufy")
            }
        }
    }
}
