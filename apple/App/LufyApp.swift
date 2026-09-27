import SwiftUI

@main
struct LufyApp: App {
    @State private var modelo = ModeloApp()

    var body: some Scene {
        WindowGroup {
            RaizView()
                .environment(modelo)
        }
        #if os(macOS)
        .defaultSize(width: 1120, height: 780)
        #endif
    }
}
