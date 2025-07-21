import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var windowManager: WindowManager
    let statusText: String
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(action: {
            openWindow(id: "main-window")
        }) {
            HStack(spacing: 8) {
                Image(systemName: "app.fill")
                Text("Show YAP")
            }
        }
        .keyboardShortcut("o", modifiers: .command)

        Divider()

        HStack {
            Text(statusText)
                .font(.caption)
            Spacer()
        }

        Divider()

        Button("Quit YAP") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}