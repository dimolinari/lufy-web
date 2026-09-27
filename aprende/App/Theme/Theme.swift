import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

enum LufyColor {
    static let paper = adaptive(light: 0xF6F7F4, dark: 0x0C0E0C)
    static let card = adaptive(light: 0xFFFFFF, dark: 0x171A17)
    static let ink = adaptive(light: 0x101410, dark: 0xF4F6F3)
    static let muted = adaptive(light: 0x5C665E, dark: 0xA8B2A9)
    static let wine = adaptive(light: 0x101410, dark: 0xF4F6F3)
    static let wineFill = adaptive(light: 0x101410, dark: 0x101410)
    static let onWine = Color(hex: 0xF4F6F3)
    static let gold = adaptive(light: 0x148A45, dark: 0x3DDC7A)
    static let line = adaptive(light: 0xE2E6E1, dark: 0x2A312C)
    static let good = adaptive(light: 0x148A45, dark: 0x3DDC7A)
    static let warn = adaptive(light: 0xD23B3B, dark: 0xFF8D86)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(light: Color(hex: light), dark: Color(hex: dark))
    }
}

extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let darkMode = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return darkMode ? NSColor(dark) : NSColor(light)
        }))
        #endif
    }
}

struct BalanceMark: View {
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let stroke = max(1.6, width * 0.07)
            Path { path in
                path.move(to: CGPoint(x: width * 0.50, y: height * 0.08))
                path.addLine(to: CGPoint(x: width * 0.50, y: height * 0.70))
                path.move(to: CGPoint(x: width * 0.22, y: height * 0.86))
                path.addLine(to: CGPoint(x: width * 0.78, y: height * 0.86))
                path.move(to: CGPoint(x: width * 0.16, y: height * 0.30))
                path.addLine(to: CGPoint(x: width * 0.84, y: height * 0.30))
            }
            .stroke(style: StrokeStyle(lineWidth: stroke, lineCap: .round))
            Path { path in
                pan(path: &path, center: CGPoint(x: width * 0.16, y: height * 0.30), width: width * 0.28, height: height * 0.16)
                pan(path: &path, center: CGPoint(x: width * 0.84, y: height * 0.30), width: width * 0.28, height: height * 0.16)
            }
            .stroke(style: StrokeStyle(lineWidth: stroke * 0.85, lineCap: .round, lineJoin: .round))
            Circle()
                .fill(LufyColor.gold)
                .frame(width: stroke * 1.7, height: stroke * 1.7)
                .position(x: width * 0.50, y: height * 0.08)
        }
        .accessibilityHidden(true)
    }

    private func pan(path: inout Path, center: CGPoint, width: CGFloat, height: CGFloat) {
        path.move(to: CGPoint(x: center.x - width / 2, y: center.y))
        path.addLine(to: CGPoint(x: center.x - width * 0.28, y: center.y + height))
        path.addLine(to: CGPoint(x: center.x + width * 0.28, y: center.y + height))
        path.addLine(to: CGPoint(x: center.x + width / 2, y: center.y))
    }
}

struct PaperScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(LufyColor.paper.ignoresSafeArea())
    }
}

struct WineHeader: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                BalanceMark()
                    .foregroundStyle(LufyColor.gold)
                    .frame(width: 36, height: 36)
                Text(title)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(LufyColor.onWine)
            }
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(LufyColor.onWine.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(LufyColor.wineFill)
        .accessibilityElement(children: .combine)
    }
}
