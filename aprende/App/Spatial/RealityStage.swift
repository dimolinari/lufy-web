import SwiftUI
import AprendeCore
#if os(iOS) || os(visionOS)
import RealityKit
#endif
#if os(iOS)
import ARKit
#endif

#if os(iOS)
enum TableMode {
    static var augmentedReality: Bool {
        ARWorldTrackingConfiguration.isSupported
    }
}
#endif

#if os(iOS)
struct ARTableStage: UIViewRepresentable {
    var exhibit: StageExhibit
    var placementRequest: Int
    var onSelect: (String) -> Void

    func makeCoordinator() -> ARCoordinator {
        ARCoordinator(onSelect: onSelect)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        view.session.run(configuration)
        let coaching = ARCoachingOverlayView()
        coaching.session = view.session
        coaching.goal = .horizontalPlane
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coaching.frame = view.bounds
        view.addSubview(coaching)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(ARCoordinator.tapped(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.view = view
        context.coordinator.onSelect = onSelect
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.onSelect = onSelect
        context.coordinator.view = uiView
        context.coordinator.sync(exhibit, placementRequest: placementRequest)
    }
}

@MainActor
final class ARCoordinator: NSObject {
    var onSelect: (String) -> Void
    weak var view: ARView?
    private var token = ""
    private var placementRequest = -1
    private var anchor: AnchorEntity?
    private var model: Entity?

    init(onSelect: @escaping (String) -> Void) {
        self.onSelect = onSelect
        super.init()
    }

    func sync(_ exhibit: StageExhibit, placementRequest: Int) {
        if self.placementRequest != placementRequest {
            self.placementRequest = placementRequest
            if let anchor, let view {
                view.scene.removeAnchor(anchor)
            }
            anchor = nil
        }
        guard token != exhibit.token else { return }
        token = exhibit.token
        model?.removeFromParent()
        let built = RealityModels.root(for: exhibit, scale: 1)
        model = built
        anchor?.addChild(built)
        if anchor != nil {
            RealityModels.rise(built)
        }
    }

    @objc func tapped(_ gesture: UITapGestureRecognizer) {
        guard let view, let model else { return }
        let point = gesture.location(in: view)
        if anchor != nil {
            let hits = view.hitTest(point, query: .nearest, mask: .all)
            if let name = hits.compactMap({ RealityModels.selectableName($0.entity) }).first {
                onSelect(name)
                return
            }
        }
        guard let result = view.raycast(from: point, allowing: .estimatedPlane, alignment: .horizontal).first else {
            return
        }
        if let anchor {
            view.scene.removeAnchor(anchor)
        }
        let placed = AnchorEntity(world: result.worldTransform)
        placed.addChild(model)
        view.scene.addAnchor(placed)
        anchor = placed
        RealityModels.rise(model)
    }
}
#endif

#if os(visionOS)
struct VolumeStage: View {
    var exhibit: StageExhibit
    var scale: Float
    var position: SIMD3<Float>
    var onSelect: (String) -> Void

    var body: some View {
        RealityView { content in
            let root = RealityModels.root(for: exhibit, scale: scale)
            root.position = position
            content.add(root)
            RealityModels.rise(root)
        }
        .gesture(
            TapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    if let name = RealityModels.selectableName(value.entity) {
                        onSelect(name)
                    }
                }
        )
        .accessibilityLabel(exhibit.accessibilityLabel)
    }
}
#endif

#if os(iOS) || os(visionOS)
@MainActor
enum RealityModels {
    static func root(for exhibit: StageExhibit, scale: Float) -> Entity {
        let root = Entity()
        root.name = "raiz"
        switch exhibit {
        case .map(let map):
            for province in map.provinces {
                if let entity = meshEntity(province.mesh, color: StageColors.region(province.region), name: province.id) {
                    root.addChild(entity)
                }
            }
        case .series(let series):
            addBars(series, to: root)
        case .hemicycle(let scene):
            for seat in scene.seats {
                let size = Float(seat.size)
                let mesh = MeshResource.generateBox(width: size, height: size * 0.7, depth: size, cornerRadius: 0.001)
                let entity = ModelEntity(mesh: mesh, materials: [lit(StageColors.vote(choice: seat.choice, recorded: seat.recorded))])
                entity.name = seat.id
                entity.position = SIMD3(Float(seat.x), size * 0.35, Float(seat.z))
                prepare(entity)
                root.addChild(entity)
            }
        }
        root.scale = SIMD3(repeating: scale)
        return root
    }

    static func rise(_ entity: Entity) {
        for child in entity.children {
            guard SpatialLink.year(fromBarID: child.name) != nil, child.scale.y < 0.5 else { continue }
            let end = Transform(scale: SIMD3(repeating: 1), translation: child.position)
            child.move(to: end, relativeTo: entity, duration: 0.8, timingFunction: .easeOut)
        }
    }

    static func selectableName(_ entity: Entity) -> String? {
        var current: Entity? = entity
        while let node = current {
            if !node.name.isEmpty, node.name != "raiz", node.name != "suelo", node.name != "linea" {
                return node.name
            }
            current = node.parent
        }
        return nil
    }

    private static func addBars(_ series: SpatialSeries, to root: Entity) {
        var tops: [SIMD3<Float>] = []
        for bar in series.bars {
            let pivot = Entity()
            pivot.name = SpatialLink.barID(year: bar.year)
            pivot.position = SIMD3(Float(bar.x), 0, 0)
            let mesh = MeshResource.generateBox(
                width: Float(bar.width),
                height: Float(bar.height),
                depth: Float(bar.depth),
                cornerRadius: 0
            )
            let box = ModelEntity(mesh: mesh, materials: [lit(StageColors.bar(belowZero: bar.belowZero))])
            box.position.y = Float(bar.height / 2)
            prepare(box)
            pivot.addChild(box)
            pivot.scale = SIMD3(1, 0.02, 1)
            root.addChild(pivot)
            tops.append(SIMD3(Float(bar.x), Float(bar.height), 0))
        }
        guard series.showsLine, tops.count >= 2 else { return }
        for index in 0..<(tops.count - 1) {
            root.addChild(tube(from: tops[index], to: tops[index + 1]))
        }
    }

    private static func meshEntity(_ mesh: SolidMesh, color: StageColor, name: String) -> ModelEntity? {
        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(mesh.vertices.count)
        var normals = Array(repeating: SIMD3<Float>(repeating: 0), count: mesh.vertices.count)
        var indices: [UInt32] = []
        indices.reserveCapacity(mesh.triangles.count * 3)
        for vertex in mesh.vertices {
            positions.append(SIMD3(Float(vertex.x), Float(vertex.y), Float(vertex.z)))
        }
        for triangle in mesh.triangles {
            indices.append(UInt32(triangle.a))
            indices.append(UInt32(triangle.b))
            indices.append(UInt32(triangle.c))
            let normal = PolygonMesh.faceNormal(triangle, mesh.vertices)
            let vector = SIMD3(Float(normal.x), Float(normal.y), Float(normal.z))
            normals[triangle.a] += vector
            normals[triangle.b] += vector
            normals[triangle.c] += vector
        }
        for index in normals.indices {
            let length = simd_length(normals[index])
            normals[index] = length > 0 ? normals[index] / length : SIMD3(0, 1, 0)
        }
        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        guard let resource = try? MeshResource.generate(from: [descriptor]) else { return nil }
        let entity = ModelEntity(mesh: resource, materials: [lit(color)])
        entity.name = name
        prepare(entity)
        return entity
    }

    private static func tube(from: SIMD3<Float>, to: SIMD3<Float>) -> Entity {
        let delta = to - from
        let length = simd_length(delta)
        let mesh = MeshResource.generateCylinder(height: length, radius: 0.0022)
        let entity = ModelEntity(mesh: mesh, materials: [lit(StageColors.line)])
        entity.name = "linea"
        entity.position = (from + to) / 2
        if length > 0 {
            entity.orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: delta / length)
        }
        return entity
    }

    private static func prepare(_ entity: ModelEntity) {
        entity.generateCollisionShapes(recursive: false)
        #if os(visionOS)
        entity.components.set(InputTargetComponent())
        #endif
    }

    private static func lit(_ color: StageColor) -> SimpleMaterial {
        SimpleMaterial(color: color, roughness: 0.55, isMetallic: false)
    }
}
#endif
