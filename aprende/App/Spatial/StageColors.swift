import Foundation
#if canImport(UIKit)
import UIKit
typealias StageColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias StageColor = NSColor
#endif

#if canImport(UIKit) || canImport(AppKit)
enum StageColors {
    static func region(_ name: String) -> StageColor {
        switch name {
        case "Costa":
            return StageColor(red: 0.05, green: 0.48, blue: 0.55, alpha: 1)
        case "Sierra":
            return StageColor(red: 0.55, green: 0.40, blue: 0.22, alpha: 1)
        case "Amazonía":
            return StageColor(red: 0.10, green: 0.42, blue: 0.24, alpha: 1)
        case "Región Insular":
            return StageColor(red: 0.13, green: 0.32, blue: 0.66, alpha: 1)
        default:
            return StageColor(red: 0.35, green: 0.38, blue: 0.36, alpha: 1)
        }
    }

    static func vote(choice: String, recorded: Bool) -> StageColor {
        guard recorded else {
            return StageColor(red: 0.78, green: 0.80, blue: 0.78, alpha: 1)
        }
        switch choice {
        case "afavor":
            return StageColor(red: 0.08, green: 0.54, blue: 0.27, alpha: 1)
        case "encontra":
            return StageColor(red: 0.82, green: 0.23, blue: 0.23, alpha: 1)
        case "abstencion":
            return StageColor(red: 0.72, green: 0.58, blue: 0.22, alpha: 1)
        case "ausente":
            return StageColor(red: 0.42, green: 0.44, blue: 0.46, alpha: 1)
        case "blanco":
            return StageColor(red: 0.93, green: 0.94, blue: 0.92, alpha: 1)
        default:
            return StageColor(red: 0.62, green: 0.64, blue: 0.62, alpha: 1)
        }
    }

    static func bar(belowZero: Bool) -> StageColor {
        if belowZero {
            return StageColor(red: 0.82, green: 0.23, blue: 0.23, alpha: 1)
        }
        return StageColor(red: 0.08, green: 0.54, blue: 0.27, alpha: 1)
    }

    static let floor = StageColor(red: 0.90, green: 0.92, blue: 0.89, alpha: 1)
    static let line = StageColor(red: 0.08, green: 0.16, blue: 0.12, alpha: 1)
    static let paper = StageColor(red: 0.96, green: 0.97, blue: 0.96, alpha: 1)
}
#endif
