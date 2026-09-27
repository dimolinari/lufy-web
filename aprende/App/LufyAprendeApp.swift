import SwiftData
import SwiftUI

@main
struct LufyAprendeApp: App {
    #if os(visionOS)
    @State private var immersionStyle: ImmersionStyle = .mixed
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: LearnerRecord.self)
        #if os(macOS)
        .defaultSize(width: 980, height: 760)
        #endif

        #if os(visionOS)
        WindowGroup(id: "volumen", for: String.self) { link in
            SpatialStudyView(link: link.wrappedValue ?? SpatialLink.map, presentation: .volume)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.8, height: 0.42, depth: 0.55, in: .meters)

        ImmersiveSpace(id: "salon", for: String.self) { link in
            SpatialStudyView(link: link.wrappedValue ?? SpatialLink.map, presentation: .room)
        }
        .immersionStyle(selection: $immersionStyle, in: .mixed)
        #endif
    }
}
