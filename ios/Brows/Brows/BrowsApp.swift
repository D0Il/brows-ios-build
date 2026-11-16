import SwiftUI

@main
struct BrowsApp: App {
    @StateObject private var model = BrowserModel()

    var body: some Scene {
        WindowGroup {
            BrowserView()
                .environmentObject(model)
        }
    }
}
