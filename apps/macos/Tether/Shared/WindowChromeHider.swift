import AppKit
import SwiftUI

struct WindowChromeHider: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configure(window: view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if context.coordinator.configuredWindow === nsView.window {
            return
        }

        DispatchQueue.main.async {
            configure(window: nsView.window, coordinator: context.coordinator)
        }
    }

    private func configure(window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }
        guard coordinator.configuredWindow !== window else { return }

        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false

        coordinator.configuredWindow = window
    }

    final class Coordinator {
        weak var configuredWindow: NSWindow?
    }
}
