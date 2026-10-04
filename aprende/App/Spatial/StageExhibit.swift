import SwiftUI
import AprendeCore

enum SpatialPresentation {
    case window
    case volume
    case room
}

enum StageExhibit: Equatable {
    case map(ReliefMap)
    case series(SpatialSeries)
    case hemicycle(HemicycleScene)

    var token: String {
        switch self {
        case .map:
            return SpatialLink.map
        case .series(let series):
            return SpatialLink.series(series.datasetID)
        case .hemicycle(let scene):
            return "\(SpatialLink.hemicycle)|\(scene.voteTitle)"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .map(let map):
            return "Mapa en tres dimensiones de \(map.provinces.count) provincias. El grosor no es altitud. Galápagos está en un recuadro."
        case .series(let series):
            return "Gráfico en tres dimensiones. \(series.title). \(series.caption)"
        case .hemicycle(let scene):
            let banner = scene.exampleData ? "\(DataCaution.exampleBanner). " : ""
            return "\(banner)Hemiciclo. Votación: \(scene.voteTitle)."
        }
    }
}

@MainActor
enum SpatialHandoff {
    static var directory: AsambleaDirectory?
}
