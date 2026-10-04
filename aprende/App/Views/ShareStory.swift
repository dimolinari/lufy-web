import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers
import AprendeCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct StoryPNG: Transferable {
    var data: Data
    var caption: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
    }
}

struct ShareStoryButton: View {
    var card: ShareCard
    var title: String
    @State private var payload: StoryPNG?
    @State private var preview: Image?
    @State private var failed = false

    var body: some View {
        Group {
            if let payload, let preview {
                ShareLink(
                    item: payload,
                    subject: Text(card.headline),
                    message: Text(card.message),
                    preview: SharePreview(card.headline, image: preview)
                ) {
                    buttonLabel
                }
            } else {
                Button(action: prepare) {
                    buttonLabel
                }
            }
        }
        .buttonStyle(.bordered)
        .tint(LufyColor.gold)
        .accessibilityHint("Abre la hoja para compartir una imagen de \(ShareCanvas.storyWidth) por \(ShareCanvas.storyHeight).")
    }

    private var buttonLabel: some View {
        Label(failed ? "No se pudo armar la tarjeta" : title, systemImage: "square.and.arrow.up")
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
    }

    private func prepare() {
        guard ShareCopyGate.isClean(card), let data = ShareRenderer.png(for: card) else {
            failed = true
            return
        }
        payload = StoryPNG(data: data, caption: card.message)
        preview = ShareImages.image(fromPNG: data)
    }
}

enum OfferingCaption {
    static func planned(_ planned: PlannedCourse) -> String {
        switch planned.offeringKind {
        case .core:
            return planned.access == .premium ? "Próximamente · curso extra" : "Próximamente"
        case .extra:
            return "Suscripción · cursos extra"
        case .earlyData:
            return "Suscripción · dato más reciente"
        case .narrated:
            return "Suscripción · audiolibro narrado"
        }
    }
}

struct SubscriptionSheet: View {
    @Environment(PremiumStore.self) private var premium
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PaperScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("El núcleo sigue gratis.")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                        Text("Las lecciones publicadas no se cobran. La suscripción, cuando está encendida, abre tres cosas: cursos extra, lecciones sobre el dato más reciente y audiolibros con narración grabada.")
                            .font(.body)
                            .foregroundStyle(LufyColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        if premium.subscriptionsEnabled {
                            if let message = premium.statusMessage {
                                Text(message)
                                    .foregroundStyle(LufyColor.warn)
                            }
                            if premium.products.isEmpty {
                                Text("No hay productos cargados. Para una prueba local, corre el esquema con App/Products.storekit.")
                                    .font(.footnote)
                                    .foregroundStyle(LufyColor.muted)
                            }
                            ForEach(premium.products) { product in
                                Button("Suscribirse: \(product.displayName) · \(product.displayPrice)") {
                                    Task { await premium.purchase(product) }
                                }
                                .buttonStyle(WineButtonStyle())
                            }
                            Button("Actualizar compras") {
                                Task { await premium.refresh() }
                            }
                            .frame(minHeight: 44)
                        } else {
                            Text("La suscripción está apagada. No hay nada que comprar.")
                                .font(.body)
                                .foregroundStyle(LufyColor.ink)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Suscripción")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}

@MainActor
enum ShareRenderer {
    static func png(for card: ShareCard) -> Data? {
        let qr = ShareImages.qrCode(payload: card.qrPayload, side: 280)
        let canvas = ShareCardCanvas(card: card, qr: qr)
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 1
        #if canImport(UIKit)
        return renderer.uiImage?.pngData()
        #elseif canImport(AppKit)
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bitmap.representation(using: .png, properties: [:])
        #else
        return nil
        #endif
    }
}

private struct ShareCardCanvas: View {
    var card: ShareCard
    var qr: Image?

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            HStack(alignment: .center) {
                Text(card.appName)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Spacer()
                if !card.labelText.isEmpty {
                    Text(card.labelText)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(card.exampleData ? Color(hex: 0xD23B3B) : Color(hex: 0x148A45))
                        .foregroundStyle(Color(hex: 0xF4F6F3))
                        .clipShape(Capsule())
                }
            }
            Text(card.headline)
                .font(.system(size: 78, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text(card.body)
                .font(.system(size: 34, weight: .regular, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            if !card.points.isEmpty {
                ShareSpark(points: card.points, kind: card.chartKind)
                    .frame(height: 420)
            }
            if !card.detail.isEmpty {
                Text(card.detail)
                    .font(.system(size: 28, weight: .regular, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if !card.sourceLine.isEmpty {
                Text(card.sourceLine)
                    .font(.system(size: 24, weight: .regular, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .bottom, spacing: 24) {
                Text(card.inviteURL.isEmpty ? card.appName : card.inviteURL)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if let qr {
                    qr.interpolation(.none)
                        .frame(width: 220, height: 220)
                        .accessibilityLabel("Código del enlace")
                }
            }
        }
        .padding(72)
        .frame(width: CGFloat(card.width), height: CGFloat(card.height), alignment: .topLeading)
        .background(Color(hex: 0xF6F7F4))
        .foregroundStyle(Color(hex: 0x101410))
    }
}

private struct ShareSpark: View {
    var points: [SharePoint]
    var kind: String

    var body: some View {
        GeometryReader { geo in
            let values = points.map(\.value)
            let low = min(values.min() ?? 0, 0)
            let high = max(values.max() ?? 0, 0)
            let span = max(high - low, 0.0001)
            let baseline = y(0, low: low, span: span, height: geo.size.height)
            ZStack(alignment: .bottomLeading) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: baseline))
                    path.addLine(to: CGPoint(x: geo.size.width, y: baseline))
                }
                .stroke(Color(hex: 0xC5CDC6), lineWidth: 2)
                if kind == "bar" {
                    bars(in: geo.size, low: low, span: span)
                } else {
                    line(in: geo.size, low: low, span: span)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func bars(in size: CGSize, low: Double, span: Double) -> some View {
        let slot = size.width / CGFloat(max(points.count, 1))
        return ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
            let height = abs(CGFloat((point.value - 0) / span)) * size.height
            let barY = point.value >= 0
                ? y(point.value, low: low, span: span, height: size.height)
                : y(0, low: low, span: span, height: size.height)
            Rectangle()
                .fill(point.value < 0 ? Color(hex: 0xD23B3B) : Color(hex: 0x148A45))
                .frame(width: slot * 0.62, height: max(height, 4))
                .position(x: slot * (CGFloat(index) + 0.5), y: barY + (point.value >= 0 ? height / 2 : -height / 2))
        }
    }

    private func line(in size: CGSize, low: Double, span: Double) -> some View {
        Path { path in
            for (index, point) in points.enumerated() {
                let x = x(index, count: points.count, width: size.width)
                let yPoint = y(point.value, low: low, span: span, height: size.height)
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: yPoint))
                } else {
                    path.addLine(to: CGPoint(x: x, y: yPoint))
                }
            }
        }
        .stroke(Color(hex: 0x148A45), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
    }

    private func x(_ index: Int, count: Int, width: CGFloat) -> CGFloat {
        guard count > 1 else { return width / 2 }
        return CGFloat(index) / CGFloat(count - 1) * width
    }

    private func y(_ value: Double, low: Double, span: Double, height: CGFloat) -> CGFloat {
        let t = (value - low) / span
        return height - CGFloat(t) * height
    }
}

enum ShareImages {
    static func qrCode(payload: String, side: CGFloat) -> Image? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let context = CIContext()
        guard let small = context.createCGImage(output, from: output.extent) else { return nil }
        let pixels = Int(side.rounded())
        guard let bitmap = CGContext(
            data: nil,
            width: pixels,
            height: pixels,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        bitmap.interpolationQuality = .none
        bitmap.draw(small, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
        guard let scaled = bitmap.makeImage() else { return nil }
        #if canImport(UIKit)
        return Image(uiImage: UIImage(cgImage: scaled))
        #elseif canImport(AppKit)
        return Image(nsImage: NSImage(cgImage: scaled, size: NSSize(width: side, height: side)))
        #else
        return nil
        #endif
    }

    static func image(fromPNG data: Data) -> Image? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        return Image(nsImage: image)
        #else
        return nil
        #endif
    }
}
