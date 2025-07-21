import Foundation
import AppKit
import SwiftUI

class WindowManager: ObservableObject {
    @Published var windowIsVisible = false

    func showWindow() {
        DispatchQueue.main.async {
            // Find and show the main window
            if let mainWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "main-window" }) {
                mainWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                self.windowIsVisible = true
            }
        }
    }

    func hideWindow() {
        DispatchQueue.main.async {
            NSApp.windows.first(where: { $0.identifier?.rawValue == "main-window" })?.orderOut(nil)
            self.windowIsVisible = false
        }
    }

    func toggleWindow() {
        if windowIsVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }
}