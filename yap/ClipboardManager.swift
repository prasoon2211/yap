import Foundation
import AppKit

class ClipboardManager {
    static func copyToClipboard(_ text: String) {
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            print("Copied to clipboard: \"\(text)\"")
        }
    }
}