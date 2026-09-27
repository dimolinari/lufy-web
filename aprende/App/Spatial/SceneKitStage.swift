import SwiftUI
import AprendeCore
#if os(iOS)
import UIKit
import SceneKit
#elseif os(macOS)
import AppKit
import SceneKit
#endif

struct OrbitStage: View {
    var exhibit: StageExhibit
    var onSelect: (String) -> Void

    var body: some View {
        #if os(iOS) || os(macOS)
        OrbitRepresentable(exhibit: exhibit, onSelect: onSelect)
            .accessibilityLabel(exhibit.accessibilityLabel)
        #else
        Color.clear
            .accessibilityLabel(exhibit.accessibilityLabel)
        #endif
    }
}

#if os(iOS)
private struct OrbitRepresentable: UIViewRepresentable {
    var exhibit: StageExhibit
    var onSelect: (String) -> Void

    func makeCoordinator() -> OrbitCoordinator {
        OrbitCoordinator(onSelect: onSelect)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = StageColors.paper
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.scene = OrbitCoordinator.makeScene()
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(OrbitCoordinator.tapped(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.view = view
        context.coordinator.sync(exhibit)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.onSelect = onSelect
        context.coordinator.view = uiView
        context.coordinator.sync(exhibit)
    }
}
#endif

#if os(macOS)
private struct OrbitRepresentable: NSViewRepresentable {
    var exhibit: StageExhibit
    var onSelect: (String) -> Void

    func makeCoordinator() -> OrbitCoordinator {
        OrbitCoordinator(onSelect: onSelect)
    }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = StageColors.paper
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.scene = OrbitCoordinator.makeScene()
        let tap = NSClickGestureRecognizer(target: context.coordinator, action: #selector(OrbitCoordinator.tapped(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.view = view
        context.coordinator.sync(exhibit)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        context.coordinator.onSelect = onSelect
        context.coordinator.view = nsView
        context.coordinator.sync(exhibit)
    }
}
#endif

#if os(iOS) || os(macOS)
@MainActor
final class OrbitCoordinator: NSObject {
    var onSelect: (String) -> Void
    weak var view: SCNView?
    private var token = ""

    init(onSelect: @escaping (String) -> Void) {
        self.onSelect = onSelect
        super.init()
    }

    static func makeScene() -> SCNScene {
        let scene = SCNScene()
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.position = SCNVector3(0.02, 0.42, 0.52)
        camera.look(at: SCNVector3(0, 0.02, 0))
        scene.rootNode.addChildNode(camera)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 700
        scene.rootNode.addChildNode(ambient)
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 900
        sun.eulerAngles = SCNVector3(-0.8, 0.4, 0)
        scene.rootNode.addChildNode(sun)
        return scene
    }

    func sync(_ exhibit: StageExhibit) {
        guard token != exhibit.token, let scene = view?.scene else { return }
        token = exhibit.token
        scene.rootNode.childNode(withName: "modelo", recursively: false)?.removeFromParentNode()
        let model = SCNNode()
        model.name = "modelo"
        StageMesh.add(exhibit, to: model)
        scene.rootNode.addChildNode(model)
    }

    @objc func tapped(_ gesture: NSObject) {
        guard let view else { return }
        let point: CGPoint
        #if os(iOS)
        guard let tap = gesture as? UITapGestureRecognizer else { return }
        point = tap.location(in: view)
        #else
        guard let tap = gesture as? NSClickGestureRecognizer else { return }
        point = tap.location(in: view)
        #endif
        let hits = view.hitTest(point, options: nil)
        guard let name = hits.compactMap({ hit -> String? in
            var node: SCNNode? = hit.node
            while let current = node {
                if let name = current.name, !name.isEmpty, name != "modelo", name != "suelo" {
                    return name
                }
                node = current.parent
            }
            return nil
        }).first else { return }
        onSelect(name)
    }
}

@MainActor
enum StageMesh {
    static func add(_ exhibit: StageExhibit, to root: SCNNode) {
        let floor = SCNPlane(width: 0.62, height: 0.46)
        floor.firstMaterial = material(StageColors.floor)
        let floorNode = SCNNode(geometry: floor)
        floorNode.name = "suelo"
        floorNode.eulerAngles.x = -.pi / 2
        floorNode.position.y = -0.001
        root.addChildNode(floorNode)
        switch exhibit {
        case .map(let map):
            for province in map.provinces {
                root.addChildNode(meshNode(province.mesh, color: StageColors.region(province.region), name: province.id))
            }
        case .series(let series):
            addBars(series, to: root)
        case .hemicycle(let scene):
            addSeats(scene, to: root)
        }
    }

    static func addBars(_ series: SpatialSeries, to root: SCNNode) {
        var tops: [SCNVector3] = []
        for bar in series.bars {
            let box = SCNBox(
                width: CGFloat(bar.width),
                height: CGFloat(bar.height),
                length: CGFloat(bar.depth),
                chamferRadius: 0
            )
            box.firstMaterial = material(StageColors.bar(belowZero: bar.belowZero))
            let node = SCNNode(geometry: box)
            node.name = SpatialLink.barID(year: bar.year)
            node.pivot = SCNMatrix4MakeTranslation(0, -SCNFloat(bar.height / 2), 0)
            node.position = SCNVector3(SCNFloat(bar.x), 0, 0)
            node.scale = SCNVector3(1, SCNFloat(0.02), 1)
            node.runAction(SCNAction.scale(to: SCNVector3(1, 1, 1), duration: 0.7))
            root.addChildNode(node)
            tops.append(SCNVector3(SCNFloat(bar.x), SCNFloat(bar.height), 0))
        }
        guard series.showsLine, tops.count >= 2 else { return }
        for index in 0..<(tops.count - 1) {
            root.addChildNode(tube(from: tops[index], to: tops[index + 1]))
        }
    }

    static func addSeats(_ scene: HemicycleScene, to root: SCNNode) {
        for seat in scene.seats {
            let box = SCNBox(width: CGFloat(seat.size), height: CGFloat(seat.size) * 0.7, length: CGFloat(seat.size), chamferRadius: 0.002)
            box.firstMaterial = material(StageColors.vote(choice: seat.choice, recorded: seat.recorded))
            let node = SCNNode(geometry: box)
            node.name = seat.id
            node.position = SCNVector3(SCNFloat(seat.x), SCNFloat(seat.size) * 0.35, SCNFloat(seat.z))
            root.addChildNode(node)
        }
    }

    private static func meshNode(_ mesh: SolidMesh, color: StageColor, name: String) -> SCNNode {
        var floats: [Float] = []
        floats.reserveCapacity(mesh.vertices.count * 3)
        for vertex in mesh.vertices {
            floats.append(Float(vertex.x))
            floats.append(Float(vertex.y))
            floats.append(Float(vertex.z))
        }
        let data = floats.withUnsafeBufferPointer { Data(buffer: $0) }
        let source = SCNGeometrySource(
            data: data,
            semantic: .vertex,
            vectorCount: mesh.vertices.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 3
        )
        var indices: [UInt32] = []
        indices.reserveCapacity(mesh.triangles.count * 3)
        for triangle in mesh.triangles {
            indices.append(UInt32(triangle.a))
            indices.append(UInt32(triangle.b))
            indices.append(UInt32(triangle.c))
        }
        let elementData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let element = SCNGeometryElement(
            data: elementData,
            primitiveType: .triangles,
            primitiveCount: mesh.triangles.count,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )
        let geometry = SCNGeometry(sources: [source], elements: [element])
        geometry.firstMaterial = material(color)
        let node = SCNNode(geometry: geometry)
        node.name = name
        return node
    }

    private static func tube(from: SCNVector3, to: SCNVector3) -> SCNNode {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let dz = to.z - from.z
        let length = sqrt(dx * dx + dy * dy + dz * dz)
        let cylinder = SCNCylinder(radius: 0.0024, height: CGFloat(length))
        cylinder.firstMaterial = material(StageColors.line)
        let node = SCNNode(geometry: cylinder)
        node.name = "linea"
        node.position = SCNVector3((from.x + to.x) / 2, (from.y + to.y) / 2, (from.z + to.z) / 2)
        node.look(at: to, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))
        return node
    }

    private static func material(_ color: StageColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .lambert
        material.isDoubleSided = true
        return material
    }
}
#endif
