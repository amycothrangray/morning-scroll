import SwiftUI

@main
struct MorningScrollApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var phase

    init() { Theme.registerFonts() }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Theme.rose)
                .task { await model.refreshStudy() }
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .active {
                model.becameActive()
                Task { await model.refreshStudy() }
            }
        }
    }
}
