import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers
import LufyCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum CodigoQR {
    static func imagen(_ texto: String, lado: CGFloat) -> CGImage? {
        guard texto.hasPrefix("https://") else { return nil }
        let filtro = CIFilter.qrCodeGenerator()
        filtro.message = Data(texto.utf8)
        filtro.correctionLevel = "M"
        guard let salida = filtro.outputImage else { return nil }
        let escala = lado / salida.extent.width
        let grande = salida.transformed(by: CGAffineTransform(scaleX: escala, y: escala))
        return CIContext().createCGImage(grande, from: grande.extent)
    }
}

struct TarjetaHistoria: View {
    let tarjeta: TarjetaCompartible

    private let vino = Color(red: 0.239216, green: 0.094118, blue: 0.125490)
    private let oro = Color(red: 0.831373, green: 0.701961, blue: 0.415686)
    private let papel = Color(red: 0.952941, green: 0.933333, blue: 0.894118)
    private let tinta = Color(red: 0.101961, green: 0.070588, blue: 0.058824)

    var body: some View {
        let ancho = CGFloat(TarjetaCompartible.pixelesAncho / TarjetaCompartible.escala)
        let alto = CGFloat(TarjetaCompartible.pixelesAlto / TarjetaCompartible.escala)
        VStack(alignment: .leading, spacing: 16) {
            Text("Lufy")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(oro)
            if let sello = tarjeta.sello {
                Text(sello.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tinta)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(oro, in: Capsule())
            }
            Text(tarjeta.titulo)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(papel)
                .lineLimit(4)
            Text(tarjeta.texto)
                .font(.system(size: 16))
                .foregroundStyle(papel)
                .lineLimit(8)
            Spacer(minLength: 0)
            Text(tarjeta.lineaFuente)
                .font(.system(size: 12))
                .foregroundStyle(oro)
                .lineLimit(3)
            HStack(alignment: .bottom, spacing: 12) {
                if let qr = CodigoQR.imagen(tarjeta.url.absoluteString, lado: 96) {
                    Image(decorative: qr, scale: 1)
                        .interpolation(.none)
                        .frame(width: 96, height: 96)
                        .background(papel)
                }
                Text(tarjeta.url.absoluteString)
                    .font(.system(size: 11))
                    .foregroundStyle(papel)
                    .lineLimit(4)
            }
        }
        .padding(28)
        .frame(width: ancho, height: alto, alignment: .topLeading)
        .background(vino)
    }
}

struct ImagenTarjeta: Transferable, Sendable {
    let png: Data

    var imagen: Image {
        #if os(macOS)
        if let ns = NSImage(data: png) {
            return Image(nsImage: ns)
        }
        #else
        if let ui = UIImage(data: png) {
            return Image(uiImage: ui)
        }
        #endif
        return Image(systemName: "square.and.arrow.up")
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { imagen in
            imagen.png
        }
    }
}

enum RenderTarjeta {
    @MainActor
    static func png(_ tarjeta: TarjetaCompartible) -> Data? {
        let ancho = CGFloat(TarjetaCompartible.pixelesAncho / TarjetaCompartible.escala)
        let alto = CGFloat(TarjetaCompartible.pixelesAlto / TarjetaCompartible.escala)
        let renderer = ImageRenderer(content: TarjetaHistoria(tarjeta: tarjeta))
        renderer.scale = CGFloat(TarjetaCompartible.escala)
        renderer.proposedSize = ProposedViewSize(width: ancho, height: alto)
        #if os(macOS)
        guard let imagen = renderer.nsImage,
              let tiff = imagen.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let datos = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return datos
        #else
        return renderer.uiImage?.pngData()
        #endif
    }
}

struct BotonTarjeta: View {
    let tarjeta: TarjetaCompartible?
    @State private var archivo: ImagenTarjeta?

    var body: some View {
        if let tarjeta {
            Group {
                if let archivo {
                    ShareLink(item: archivo, preview: SharePreview("Lufy", image: archivo.imagen)) {
                        Label("Tarjeta", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .frame(minHeight: 44)
            .accessibilityLabel("Compartir tarjeta de Lufy")
            .task(id: identidad(tarjeta)) {
                if let datos = RenderTarjeta.png(tarjeta) {
                    archivo = ImagenTarjeta(png: datos)
                }
            }
        }
    }

    private func identidad(_ tarjeta: TarjetaCompartible) -> String {
        "\(tarjeta.sello?.rawValue ?? "")|\(tarjeta.titulo)|\(tarjeta.lineaFuente)|\(tarjeta.url.absoluteString)"
    }
}
