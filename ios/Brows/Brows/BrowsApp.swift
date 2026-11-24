import SwiftUI

@main
struct BrowsApp: App {
    @StateObject private var model = BrowserModel()

    var body: some Scene {
        WindowGroup {
            BrowserView()
                .environmentObject(model)
        }
        .commands {
            // A hardware keyboard on an iPad is a first-class way to drive a
            // browser -- Safari and Chrome both answer these keys. Without a
            // command set the keyboard can only type into fields, and the
            // browser itself is unreachable from it.
            CommandGroup(after: .newItem) {
                Button("New Tab") { model.newTab() }
                    .keyboardShortcut("t", modifiers: .command)
                Button("New Private Tab") { model.newTab(private: true) }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Close Tab") {
                    if let tab = model.activeTab { model.close(tab) }
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            CommandMenu("Page") {
                Button("Reload") { model.reloadOrStop() }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Find in Page") { model.startFind() }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Next Match") { model.runFind() }
                    .keyboardShortcut("g", modifiers: .command)
                Button("Previous Match") { model.runFind(backwards: true) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Divider()
                Button("Back") { model.goBack() }
                    .keyboardShortcut("[", modifiers: .command)
                Button("Forward") { model.goForward() }
                    .keyboardShortcut("]", modifiers: .command)
            }
            CommandMenu("Tabs") {
                ForEach(1...9, id: \.self) { number in
                    Button("Tab " + String(number)) {
                        let index = number - 1
                        if model.tabs.indices.contains(index) { model.select(model.tabs[index]) }
                    }
                    .keyboardShortcut(KeyEquivalent(Character(String(number))), modifiers: .command)
                }
            }
        }
    }
}
