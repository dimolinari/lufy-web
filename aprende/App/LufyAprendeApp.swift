import SwiftData
import SwiftUI

@main
struct LufyAprendeApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: LearnerRecord.self)
        #if os(macOS)
        .defaultSize(width: 980, height: 760)
        #endif
    }
}
