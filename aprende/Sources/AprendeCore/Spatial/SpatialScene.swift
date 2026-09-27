import Foundation

public enum EvidenceMark: String, Codable, CaseIterable, Sendable {
    case confirmado = "CONFIRMADO"
    case indicio = "INDICIO"
    case abierto = "ABIERTO"
    case hipotesis = "HIPOTESIS"
}

public struct PlanarPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct MeshVertex: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

public struct IndexedTriangle: Equatable, Sendable {
    public var a: Int
    public var b: Int
    public var c: Int

    public init(a: Int, b: Int, c: Int) {
        self.a = a
        self.b = b
        self.c = c
    }
}

public struct SolidMesh: Equatable, Sendable {
    public var vertices: [MeshVertex]
    public var triangles: [IndexedTriangle]

    public init(vertices: [MeshVertex], triangles: [IndexedTriangle]) {
        self.vertices = vertices
        self.triangles = triangles
    }
}

public enum PolygonMesh {
    public static func triangulate(_ points: [PlanarPoint]) -> [IndexedTriangle]? {
        guard points.count >= 3 else { return nil }
        var working = Array(points.indices)
        if signedArea(points) < 0 {
            working.reverse()
        }
        var triangles: [IndexedTriangle] = []
        var guardCount = 0
        while working.count > 3 && guardCount < 20_000 {
            guardCount += 1
            let count = working.count
            var found = false
            for cursor in 0..<count {
                let i0 = working[(cursor - 1 + count) % count]
                let i1 = working[cursor]
                let i2 = working[(cursor + 1) % count]
                let a = points[i0]
                let b = points[i1]
                let c = points[i2]
                if cross(a, b, c) <= 1e-12 { continue }
                var blocked = false
                for other in working where other != i0 && other != i1 && other != i2 {
                    if strictlyInside(points[other], a, b, c) {
                        blocked = true
                        break
                    }
                }
                if blocked { continue }
                triangles.append(IndexedTriangle(a: i0, b: i1, c: i2))
                working.remove(at: cursor)
                found = true
                break
            }
            if !found { return nil }
        }
        if working.count == 3 {
            triangles.append(IndexedTriangle(a: working[0], b: working[1], c: working[2]))
        }
        return triangles
    }

    /// Extruye anillos en el plano x/z. La altura `thickness` es uniforme.
    public static func extrude(rings: [[PlanarPoint]], thickness: Double) -> SolidMesh {
        var vertices: [MeshVertex] = []
        var triangles: [IndexedTriangle] = []
        let height = max(thickness, 0)
        for ring in rings where ring.count >= 3 {
            guard let faces = triangulate(ring) else { continue }
            let base = vertices.count
            let count = ring.count
            var centroidX = 0.0
            var centroidZ = 0.0
            for point in ring {
                vertices.append(MeshVertex(x: point.x, y: height, z: point.y))
                centroidX += point.x
                centroidZ += point.y
            }
            centroidX /= Double(count)
            centroidZ /= Double(count)
            for point in ring {
                vertices.append(MeshVertex(x: point.x, y: 0, z: point.y))
            }
            for face in faces {
                triangles.append(IndexedTriangle(a: base + face.a, b: base + face.c, c: base + face.b))
                triangles.append(IndexedTriangle(
                    a: base + count + face.a,
                    b: base + count + face.b,
                    c: base + count + face.c
                ))
            }
            for index in 0..<count {
                let next = (index + 1) % count
                let top0 = base + index
                let top1 = base + next
                let bottom0 = base + count + index
                let bottom1 = base + count + next
                var outward = IndexedTriangle(a: bottom0, b: bottom1, c: top1)
                let edgeX = (vertices[bottom0].x + vertices[bottom1].x) / 2 - centroidX
                let edgeZ = (vertices[bottom0].z + vertices[bottom1].z) / 2 - centroidZ
                let normal = faceNormal(outward, vertices)
                if normal.x * edgeX + normal.z * edgeZ < 0 {
                    outward = IndexedTriangle(a: bottom0, b: top1, c: bottom1)
                    triangles.append(outward)
                    triangles.append(IndexedTriangle(a: bottom0, b: top0, c: top1))
                } else {
                    triangles.append(outward)
                    triangles.append(IndexedTriangle(a: bottom0, b: top1, c: top0))
                }
            }
        }
        return SolidMesh(vertices: vertices, triangles: triangles)
    }

    public static func faceNormal(_ triangle: IndexedTriangle, _ vertices: [MeshVertex]) -> (x: Double, y: Double, z: Double) {
        let p0 = vertices[triangle.a]
        let p1 = vertices[triangle.b]
        let p2 = vertices[triangle.c]
        let ax = p1.x - p0.x
        let ay = p1.y - p0.y
        let az = p1.z - p0.z
        let bx = p2.x - p0.x
        let by = p2.y - p0.y
        let bz = p2.z - p0.z
        return (ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx)
    }

    private static func signedArea(_ points: [PlanarPoint]) -> Double {
        var total = 0.0
        for index in points.indices {
            let current = points[index]
            let next = points[(index + 1) % points.count]
            total += current.x * next.y - next.x * current.y
        }
        return total / 2
    }

    private static func cross(_ a: PlanarPoint, _ b: PlanarPoint, _ c: PlanarPoint) -> Double {
        (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    }

    private static func strictlyInside(_ point: PlanarPoint, _ a: PlanarPoint, _ b: PlanarPoint, _ c: PlanarPoint) -> Bool {
        let c1 = cross(a, b, point)
        let c2 = cross(b, c, point)
        let c3 = cross(c, a, point)
        return c1 > 1e-10 && c2 > 1e-10 && c3 > 1e-10
    }
}

public struct BoundaryProvince: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var region: String
    public var inset: Bool
    public var rings: [[[Double]]]

    public init(id: String, name: String, region: String, inset: Bool, rings: [[[Double]]]) {
        self.id = id
        self.name = name
        self.region = region
        self.inset = inset
        self.rings = rings
    }
}

public struct BoundaryDocument: Codable, Equatable, Sendable {
    public var schema: String
    public var license: String
    public var attribution: String
    public var elevationIncluded: Bool
    public var elevationNote: String
    public var insetNote: String
    public var regionNote: String
    public var provinces: [BoundaryProvince]

    public init(
        schema: String,
        license: String,
        attribution: String,
        elevationIncluded: Bool,
        elevationNote: String,
        insetNote: String,
        regionNote: String,
        provinces: [BoundaryProvince]
    ) {
        self.schema = schema
        self.license = license
        self.attribution = attribution
        self.elevationIncluded = elevationIncluded
        self.elevationNote = elevationNote
        self.insetNote = insetNote
        self.regionNote = regionNote
        self.provinces = provinces
    }
}

public struct ProvinceSolid: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var region: String
    public var inset: Bool
    public var evidence: EvidenceMark
    public var mesh: SolidMesh
    public var label: MeshVertex

    public init(
        id: String,
        name: String,
        region: String,
        inset: Bool,
        evidence: EvidenceMark,
        mesh: SolidMesh,
        label: MeshVertex
    ) {
        self.id = id
        self.name = name
        self.region = region
        self.inset = inset
        self.evidence = evidence
        self.mesh = mesh
        self.label = label
    }
}

public struct ReliefMap: Equatable, Sendable {
    public var provinces: [ProvinceSolid]
    public var license: String
    public var attribution: String
    public var elevationIncluded: Bool
    public var elevationNote: String
    public var insetNote: String
    public var regionNote: String
    public var longerSide: Double
    public var thickness: Double

    public init(
        provinces: [ProvinceSolid],
        license: String,
        attribution: String,
        elevationIncluded: Bool,
        elevationNote: String,
        insetNote: String,
        regionNote: String,
        longerSide: Double,
        thickness: Double
    ) {
        self.provinces = provinces
        self.license = license
        self.attribution = attribution
        self.elevationIncluded = elevationIncluded
        self.elevationNote = elevationNote
        self.insetNote = insetNote
        self.regionNote = regionNote
        self.longerSide = longerSide
        self.thickness = thickness
    }

    public func province(id: String) -> ProvinceSolid? {
        provinces.first { $0.id == id }
    }
}

public enum ReliefMapBuilder {
    public static let schema = "lufy.limites.v1"
    public static let tableSide = 0.34
    public static let tableThickness = 0.014

    public static func loadBundled(longerSide: Double = tableSide, thickness: Double = tableThickness) throws -> ReliefMap {
        guard let url = Bundle.module.url(forResource: "provincias-limites", withExtension: "json", subdirectory: "Spatial")
            ?? Bundle.module.url(forResource: "provincias-limites", withExtension: "json")
        else {
            throw ContentError.invalid("No está el mapa de provincias.")
        }
        return try build(from: Data(contentsOf: url), longerSide: longerSide, thickness: thickness)
    }

    public static func build(from data: Data, longerSide: Double = tableSide, thickness: Double = tableThickness) throws -> ReliefMap {
        let document = try JSONDecoder().decode(BoundaryDocument.self, from: data)
        guard document.schema == schema else {
            throw ContentError.invalid("El mapa no usa el esquema \(schema).")
        }
        guard document.elevationIncluded == false else {
            throw ContentError.invalid("Este mapa no debe incluir elevación empaquetada.")
        }
        guard OpenLicense.isAllowed(document.license) else {
            throw ContentError.invalid("La licencia del mapa no es dominio público ni CC BY.")
        }
        let span = max(longerSide, 0.05)
        let height = max(thickness, 0.001)
        let originLat = -1.5
        let cosLat = cos(originLat * .pi / 180)
        let mainland = document.provinces.filter { !$0.inset }
        let mainlandPoints = mainland.flatMap { province in province.rings.flatMap { $0 } }
        guard !mainlandPoints.isEmpty else {
            throw ContentError.invalid("El mapa no tiene continente.")
        }
        let projected = mainlandPoints.map { point in
            PlanarPoint(x: point[0] * cosLat, y: point[1])
        }
        let minX = projected.map(\.x).min() ?? 0
        let maxX = projected.map(\.x).max() ?? 0
        let minY = projected.map(\.y).min() ?? 0
        let maxY = projected.map(\.y).max() ?? 0
        let rawSpan = max(maxX - minX, maxY - minY)
        guard rawSpan > 0 else {
            throw ContentError.invalid("El mapa continental no tiene extensión.")
        }
        let scale = span / rawSpan
        let midX = (minX + maxX) / 2
        let midY = (minY + maxY) / 2

        func placeMainland(_ lon: Double, _ lat: Double) -> PlanarPoint {
            PlanarPoint(x: (lon * cosLat - midX) * scale, y: (lat - midY) * scale)
        }

        var solids: [ProvinceSolid] = []
        for province in document.provinces where !province.inset {
            let rings = try rings(of: province) { placeMainland($0, $1) }
            solids.append(solid(province, rings: rings, evidence: .confirmado, thickness: height))
        }

        let mainlandMinX = solids.flatMap(\.mesh.vertices).map(\.x).min() ?? 0
        if let islands = document.provinces.first(where: \.inset) {
            let islandPoints = islands.rings.flatMap { $0 }
            let islandPlane = islandPoints.map { PlanarPoint(x: $0[0] * cosLat, y: $0[1]) }
            let iMinX = islandPlane.map(\.x).min() ?? 0
            let iMaxX = islandPlane.map(\.x).max() ?? 0
            let iMinY = islandPlane.map(\.y).min() ?? 0
            let iMaxY = islandPlane.map(\.y).max() ?? 0
            let islandSpan = max(iMaxX - iMinX, iMaxY - iMinY)
            guard islandSpan > 0 else {
                throw ContentError.invalid("El recuadro insular no tiene extensión.")
            }
            let islandLonger = span * 0.26
            let islandScale = islandLonger / islandSpan
            let gap = span * 0.08
            let placedWidth = (iMaxX - iMinX) * islandScale
            let targetMidX = mainlandMinX - gap - placedWidth / 2
            let targetMidY = 0.0
            let sourceMidX = (iMinX + iMaxX) / 2
            let sourceMidY = (iMinY + iMaxY) / 2
            let rings = try rings(of: islands) { lon, lat in
                let raw = PlanarPoint(x: lon * cosLat, y: lat)
                return PlanarPoint(
                    x: targetMidX + (raw.x - sourceMidX) * islandScale,
                    y: targetMidY + (raw.y - sourceMidY) * islandScale
                )
            }
            solids.append(solid(islands, rings: rings, evidence: .confirmado, thickness: height))
        }

        return ReliefMap(
            provinces: solids,
            license: document.license,
            attribution: document.attribution,
            elevationIncluded: false,
            elevationNote: document.elevationNote,
            insetNote: document.insetNote,
            regionNote: document.regionNote,
            longerSide: span,
            thickness: height
        )
    }

    private static func rings(
        of province: BoundaryProvince,
        place: (Double, Double) -> PlanarPoint
    ) throws -> [[PlanarPoint]] {
        var output: [[PlanarPoint]] = []
        for ring in province.rings {
            let points = ring.map { pair -> PlanarPoint in
                place(pair.count > 0 ? pair[0] : 0, pair.count > 1 ? pair[1] : 0)
            }
            guard points.count >= 3 else {
                throw ContentError.invalid("La provincia \(province.name) tiene un contorno demasiado corto.")
            }
            guard PolygonMesh.triangulate(points) != nil else {
                throw ContentError.invalid("No se pudo cerrar el contorno de \(province.name).")
            }
            output.append(points)
        }
        guard !output.isEmpty else {
            throw ContentError.invalid("La provincia \(province.name) no tiene contorno.")
        }
        return output
    }

    private static func solid(
        _ province: BoundaryProvince,
        rings: [[PlanarPoint]],
        evidence: EvidenceMark,
        thickness: Double
    ) -> ProvinceSolid {
        let mesh = PolygonMesh.extrude(rings: rings, thickness: thickness)
        let outer = rings[0]
        let count = Double(outer.count)
        let label = MeshVertex(
            x: outer.reduce(0) { $0 + $1.x } / count,
            y: thickness,
            z: outer.reduce(0) { $0 + $1.y } / count
        )
        return ProvinceSolid(
            id: province.id,
            name: province.name,
            region: province.region,
            inset: province.inset,
            evidence: evidence,
            mesh: mesh,
            label: label
        )
    }
}

public struct RaisedBar: Equatable, Sendable, Identifiable {
    public var year: Int
    public var value: Double
    public var belowZero: Bool
    public var x: Double
    public var height: Double
    public var width: Double
    public var depth: Double

    public var id: Int { year }

    public init(year: Int, value: Double, belowZero: Bool, x: Double, height: Double, width: Double, depth: Double) {
        self.year = year
        self.value = value
        self.belowZero = belowZero
        self.x = x
        self.height = height
        self.width = width
        self.depth = depth
    }
}

public struct SpatialSeries: Equatable, Sendable {
    public var datasetID: String
    public var title: String
    public var unit: String
    public var showsLine: Bool
    public var exampleData: Bool
    public var evidence: EvidenceMark?
    public var caption: String
    public var bars: [RaisedBar]

    public init(
        datasetID: String,
        title: String,
        unit: String,
        showsLine: Bool,
        exampleData: Bool,
        evidence: EvidenceMark?,
        caption: String,
        bars: [RaisedBar]
    ) {
        self.datasetID = datasetID
        self.title = title
        self.unit = unit
        self.showsLine = showsLine
        self.exampleData = exampleData
        self.evidence = evidence
        self.caption = caption
        self.bars = bars
    }

    public func bar(year: Int) -> RaisedBar? {
        bars.first { $0.year == year }
    }
}

public enum SpatialSeriesLayout {
    public static let maxHeight = 0.12
    public static let tableWidth = 0.34

    public static func make(_ dataset: StudyDataset) -> SpatialSeries {
        let points = dataset.points.sorted { $0.year < $1.year }
        let maxAbs = points.map { abs($0.value) }.max() ?? 0
        let count = points.count
        let slot = count > 0 ? tableWidth / Double(count) : tableWidth
        let slim = dataset.kind == "line"
        let barWidth = slot * (slim ? 0.28 : 0.62)
        let depth = min(max(barWidth, 0.008), 0.028)
        var bars: [RaisedBar] = []
        for (index, point) in points.enumerated() {
            let fraction = maxAbs > 0 ? abs(point.value) / maxAbs : 0
            var height = maxHeight * fraction
            if height < 0.006 {
                height = point.value == 0 ? 0.004 : 0.006
            }
            let x = -tableWidth / 2 + slot * (Double(index) + 0.5)
            bars.append(RaisedBar(
                year: point.year,
                value: point.value,
                belowZero: point.value < 0,
                x: x,
                height: height,
                width: barWidth,
                depth: depth
            ))
        }
        return SpatialSeries(
            datasetID: dataset.id,
            title: dataset.title,
            unit: dataset.unit,
            showsLine: slim,
            exampleData: dataset.exampleData,
            evidence: dataset.exampleData ? nil : .confirmado,
            caption: DataCaution.caption(dataset),
            bars: bars
        )
    }
}

public struct HemicycleSeat: Equatable, Sendable, Identifiable {
    public var id: String
    public var publicName: String
    public var party: String
    public var district: String
    public var choice: String
    public var choiceLabel: String
    public var recorded: Bool
    public var x: Double
    public var z: Double
    public var size: Double

    public init(
        id: String,
        publicName: String,
        party: String,
        district: String,
        choice: String,
        choiceLabel: String,
        recorded: Bool,
        x: Double,
        z: Double,
        size: Double
    ) {
        self.id = id
        self.publicName = publicName
        self.party = party
        self.district = district
        self.choice = choice
        self.choiceLabel = choiceLabel
        self.recorded = recorded
        self.x = x
        self.z = z
        self.size = size
    }
}

public struct HemicycleScene: Equatable, Sendable {
    public var exampleData: Bool
    public var voteTitle: String
    public var sourceLine: String
    public var seats: [HemicycleSeat]
    public var titles: [String]
    public var updatedAt: String

    public init(
        exampleData: Bool,
        voteTitle: String,
        sourceLine: String,
        seats: [HemicycleSeat],
        titles: [String],
        updatedAt: String
    ) {
        self.exampleData = exampleData
        self.voteTitle = voteTitle
        self.sourceLine = sourceLine
        self.seats = seats
        self.titles = titles
        self.updatedAt = updatedAt
    }

    public func seat(id: String) -> HemicycleSeat? {
        seats.first { $0.id == id }
    }
}

public enum HemicycleLayout {
    public static let absentLabel = "Sin registro en esta votación"

    public static func scene(from directory: AsambleaDirectory, voteTitle: String? = nil, radius: Double = 0.12) -> HemicycleScene {
        var counts: [String: Int] = [:]
        for person in directory.legislators {
            for vote in person.votes {
                counts[vote.title, default: 0] += 1
            }
        }
        let titles = counts.keys.sorted { left, right in
            let leftCount = counts[left] ?? 0
            let rightCount = counts[right] ?? 0
            if leftCount != rightCount { return leftCount > rightCount }
            return left < right
        }
        let chosen: String
        if let voteTitle, titles.contains(voteTitle) {
            chosen = voteTitle
        } else {
            chosen = titles.first ?? ""
        }
        let people = directory.legislators
        let count = people.count
        let start = 15.0 * Double.pi / 180
        let end = 165.0 * Double.pi / 180
        let span = max(radius, 0.04)
        var seats: [HemicycleSeat] = []
        var sourceLine = "\(directory.source.institution). \(directory.source.dataset). \(directory.source.date)."
        for (index, person) in people.enumerated() {
            let portion = count <= 1 ? 0.5 : Double(index) / Double(count - 1)
            let angle = start + (end - start) * portion
            let vote = person.votes.first { $0.title == chosen }
            if let vote, sourceLine == "\(directory.source.institution). \(directory.source.dataset). \(directory.source.date)." {
                sourceLine = vote.source
            }
            seats.append(HemicycleSeat(
                id: person.id,
                publicName: person.publicName,
                party: person.party,
                district: person.district,
                choice: vote?.choice ?? "",
                choiceLabel: vote?.choiceLabel ?? absentLabel,
                recorded: vote != nil,
                x: cos(angle) * span,
                z: sin(angle) * span,
                size: 0.02
            ))
        }
        if let recorded = people.compactMap({ person in person.votes.first { $0.title == chosen } }).first {
            sourceLine = recorded.source
        }
        return HemicycleScene(
            exampleData: directory.exampleData,
            voteTitle: chosen,
            sourceLine: sourceLine,
            seats: seats,
            titles: titles,
            updatedAt: directory.updatedAt
        )
    }
}

public enum SpatialLink {
    public static let map = "espacio:mapa"
    public static let hemicycle = "espacio:hemiciclo"

    public static func series(_ id: String) -> String {
        "espacio:serie:\(id)"
    }

    public static func barID(year: Int) -> String {
        "barra:\(year)"
    }

    public static func year(fromBarID id: String) -> Int? {
        let prefix = "barra:"
        guard id.hasPrefix(prefix) else { return nil }
        return Int(id.dropFirst(prefix.count))
    }

    public enum Kind: Equatable, Sendable {
        case map
        case series(String)
        case hemicycle
    }

    public static func parse(_ value: String) -> Kind? {
        if value == map { return .map }
        if value == hemicycle { return .hemicycle }
        let prefix = "espacio:serie:"
        guard value.hasPrefix(prefix) else { return nil }
        let id = String(value.dropFirst(prefix.count))
        guard !id.isEmpty else { return nil }
        return .series(id)
    }
}

public enum SpatialNarration {
    public static func script(for kind: SpatialLink.Kind, exampleData: Bool) -> String {
        switch kind {
        case .map:
            return """
            Este mapa está sobre la mesa para que puedas rodearlo. El grosor es el mismo en todas las provincias: no mide la altura de los Andes ni de la Costa. No hay un modelo de elevación en la app. La forma sale de los límites abiertos de geoBoundaries, licencia CC0. Galápagos está en un recuadro al oeste. No está a la distancia real. Las regiones son Costa, Sierra, Amazonía y Región Insular. Toca una provincia y verás su nombre, su región y la marca CONFIRMADO: es la clasificación de esta lección, no una altitud.
            """
        case .series:
            let caution = exampleData
                ? "Esta serie dice DATOS DE EJEMPLO. Esos números no son oficiales. "
                : "La marca CONFIRMADO acompaña a la fuente que está debajo, no a una opinión. "
            return """
            Las barras salen de la mesa según el valor absoluto de la serie. Si el número es negativo, la barra es roja: el color describe el signo, no un consejo de compra ni de venta. \(caution)Recorre el año en la ficha. La institución, el indicador y la fecha van en la misma pantalla.
            """
        case .hemicycle:
            let banner = exampleData
                ? "DATOS DE EJEMPLO. Los nombres y los votos de esta copia son ficticios. "
                : ""
            return """
            \(banner)El hemiciclo es un esquema de los escaños que trae el archivo del día. El color es el voto registrado en esa votación: a favor, en contra, abstención, ausente o blanco. Si una persona no tiene registro en esa votación, el escaño queda sin color de voto. No es un juicio sobre nadie.
            """
        }
    }
}
