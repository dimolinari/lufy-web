import XCTest
@testable import AprendeCore

final class SpatialTests: XCTestCase {
    func testSquareExtrudesWithUniformThickness() {
        let square = [
            PlanarPoint(x: 0, y: 0),
            PlanarPoint(x: 1, y: 0),
            PlanarPoint(x: 1, y: 1),
            PlanarPoint(x: 0, y: 1),
        ]
        let faces = PolygonMesh.triangulate(square)
        XCTAssertEqual(faces?.count, 2)
        let mesh = PolygonMesh.extrude(rings: [square], thickness: 0.014)
        XCTAssertEqual(mesh.vertices.count, 8)
        XCTAssertEqual(mesh.triangles.count, 12)
        XCTAssertTrue(mesh.vertices.allSatisfy { $0.y == 0 || $0.y == 0.014 })
        let top = mesh.triangles.filter { triangle in
            [triangle.a, triangle.b, triangle.c].allSatisfy { mesh.vertices[$0].y == 0.014 }
        }
        XCTAssertEqual(top.count, 2)
        let normalY = top.reduce(0.0) { sum, triangle in
            sum + PolygonMesh.faceNormal(triangle, mesh.vertices).y
        }
        XCTAssertGreaterThan(normalY, 0)
    }

    func testConcaveRingTriangulates() {
        let shape = [
            PlanarPoint(x: 0, y: 0),
            PlanarPoint(x: 3, y: 0),
            PlanarPoint(x: 3, y: 1),
            PlanarPoint(x: 1, y: 1),
            PlanarPoint(x: 1, y: 2),
            PlanarPoint(x: 3, y: 2),
            PlanarPoint(x: 3, y: 3),
            PlanarPoint(x: 0, y: 3),
        ]
        let faces = PolygonMesh.triangulate(shape)
        XCTAssertEqual(faces?.count, 6)
    }

    func testBundledReliefUsesOpenBoundariesWithoutElevation() throws {
        let map = try ReliefMapBuilder.loadBundled()
        XCTAssertEqual(map.provinces.count, 24)
        XCTAssertFalse(map.elevationIncluded)
        XCTAssertTrue(map.elevationNote.localizedCaseInsensitiveContains("altitud"))
        XCTAssertTrue(map.attribution.contains("geoBoundaries"))
        XCTAssertTrue(map.attribution.contains("CC0"))
        XCTAssertTrue(OpenLicense.isAllowed(map.license))
        let regions = Set(map.provinces.map(\.region))
        XCTAssertEqual(regions, ["Costa", "Sierra", "Amazonía", "Región Insular"])
        let islands = try XCTUnwrap(map.provinces.first { $0.inset })
        XCTAssertEqual(islands.id, "galapagos")
        XCTAssertEqual(islands.evidence, .confirmado)
        let islandMaxX = islands.mesh.vertices.map(\.x).max() ?? 0
        let mainland = map.provinces.filter { !$0.inset }
        let mainlandMinX = mainland.flatMap(\.mesh.vertices).map(\.x).min() ?? 0
        XCTAssertLessThan(islandMaxX, mainlandMinX)
        for province in map.provinces {
            XCTAssertFalse(province.mesh.triangles.isEmpty, province.id)
            XCTAssertTrue(province.mesh.vertices.allSatisfy { $0.y == 0 || $0.y == map.thickness }, province.id)
        }
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "provincias-limites", withExtension: "json", subdirectory: "Spatial")
        )
        let bytes = try Data(contentsOf: url).count
        XCTAssertLessThan(bytes, 200_000)
    }

    func testChartBarsRiseAndKeepTheSign() throws {
        let library = try FigureLibrary.loadBundled()
        let growth = try XCTUnwrap(library.dataset(id: "crecimiento-pib"))
        let series = SpatialSeriesLayout.make(growth)
        XCTAssertFalse(series.exampleData)
        XCTAssertEqual(series.evidence, .confirmado)
        XCTAssertFalse(series.showsLine)
        XCTAssertTrue(series.bars.contains { $0.belowZero && $0.year == 2024 })
        XCTAssertTrue(series.bars.allSatisfy { $0.height > 0 && $0.height <= SpatialSeriesLayout.maxHeight + 0.0001 })
        let tallest = try XCTUnwrap(series.bars.max { $0.height < $1.height })
        let largest = try XCTUnwrap(growth.points.max { abs($0.value) < abs($1.value) })
        XCTAssertEqual(tallest.year, largest.year)
        let ordered = series.bars.map(\.x)
        XCTAssertEqual(ordered, ordered.sorted())
        let oil = try XCTUnwrap(library.dataset(id: "rentas-petroleo"))
        XCTAssertTrue(SpatialSeriesLayout.make(oil).showsLine)
        var invented = growth
        invented.exampleData = true
        let sample = SpatialSeriesLayout.make(invented)
        XCTAssertNil(sample.evidence)
        XCTAssertTrue(sample.caption.contains(DataCaution.exampleBanner))
    }

    func testExampleHemicycleColorsOnlyTheRecordedVote() throws {
        let directory = try FeedLibrary.loadBundled()
        let scene = HemicycleLayout.scene(from: directory)
        XCTAssertTrue(scene.exampleData)
        XCTAssertEqual(scene.seats.count, 6)
        XCTAssertTrue(scene.seats.allSatisfy { $0.publicName.contains("Ejemplo") })
        XCTAssertEqual(scene.voteTitle, "Texto imaginario de un segundo debate")
        let recorded = scene.seats.filter(\.recorded)
        XCTAssertEqual(Set(recorded.map(\.choice)), ["blanco", "afavor"])
        XCTAssertEqual(scene.seats.filter { !$0.recorded }.count, 4)
        XCTAssertTrue(scene.seats.filter { !$0.recorded }.allSatisfy { $0.choiceLabel == HemicycleLayout.absentLabel })
        let positions = Set(scene.seats.map { "\($0.x),\($0.z)" })
        XCTAssertEqual(positions.count, scene.seats.count)
        XCTAssertTrue(scene.seats.allSatisfy { $0.z > 0 })
        let again = HemicycleLayout.scene(from: directory, voteTitle: "Texto imaginario sobre calendarios escolares")
        XCTAssertEqual(again.seats.filter(\.recorded).count, 2)
        XCTAssertTrue(again.exampleData)
    }

    func testEvidenceMarksAndSpatialLinksStayNarrow() {
        XCTAssertEqual(
            EvidenceMark.allCases.map(\.rawValue).sorted(),
            ["ABIERTO", "CONFIRMADO", "HIPOTESIS", "INDICIO"]
        )
        XCTAssertEqual(SpatialLink.parse(SpatialLink.map), .map)
        XCTAssertEqual(SpatialLink.parse(SpatialLink.hemicycle), .hemicycle)
        XCTAssertEqual(SpatialLink.parse(SpatialLink.series("deuda-externa")), .series("deuda-externa"))
        XCTAssertNil(SpatialLink.parse("como-se-hace-una-ley"))
        XCTAssertNil(SpatialLink.parse("tu-provincia"))
        XCTAssertEqual(SpatialLink.year(fromBarID: SpatialLink.barID(year: 2020)), 2020)
        let mapWords = SpatialNarration.script(for: .map, exampleData: false)
        XCTAssertTrue(mapWords.localizedCaseInsensitiveContains("altitud"))
        XCTAssertTrue(mapWords.contains("CC0"))
        XCTAssertTrue(mapWords.contains(EvidenceMark.confirmado.rawValue))
        let sample = SpatialNarration.script(for: .hemicycle, exampleData: true)
        XCTAssertTrue(sample.contains(DataCaution.exampleBanner))
        let official = SpatialNarration.script(for: .hemicycle, exampleData: false)
        XCTAssertFalse(official.contains(DataCaution.exampleBanner))
    }
}
