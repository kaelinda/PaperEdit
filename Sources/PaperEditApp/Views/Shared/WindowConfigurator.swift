import AppKit
import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = false
            window.toolbarStyle = .automatic
            window.styleMask.remove(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.backgroundColor = .windowBackgroundColor
            window.isOpaque = true
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
