import AppKit
import SwiftUI

/// Environment flag controlling whether the graph canvas responds to scroll and
/// magnify input. Set to `false` while a modal overlay covers the workspace so the
/// overlay's own scrolling is not hijacked by the graph viewport.
private struct GraphCanvasInputEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var graphCanvasInputEnabled: Bool {
        get { self[GraphCanvasInputEnabledKey.self] }
        set { self[GraphCanvasInputEnabledKey.self] = newValue }
    }
}

/// Bridges macOS scroll-wheel and magnify events into SwiftUI graph gestures.
struct MacCanvasEventBridge: NSViewRepresentable {
    /// Whether the bridge should consume scroll and magnify events. Disabled while a
    /// modal overlay (such as settings) is presented so it does not steal scrolling.
    var isEnabled: Bool = true
    let onScroll: (CGSize) -> Void
    let onMagnify: (CGFloat) -> Void

    /// Creates the coordinator that owns the local NSEvent monitor.
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Creates the hosting NSView used to scope local input events.
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.view = view
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onScroll = onScroll
        context.coordinator.onMagnify = onMagnify
        context.coordinator.installMonitor()
        return view
    }

    /// Updates event callbacks when SwiftUI refreshes the bridge.
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.view = nsView
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onScroll = onScroll
        context.coordinator.onMagnify = onMagnify
    }

    /// Removes the local monitor when the NSView leaves the hierarchy.
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    /// Owns the NSEvent monitor for this graph viewport.
    final class Coordinator {
        weak var view: NSView?
        var isEnabled = true
        var onScroll: ((CGSize) -> Void)?
        var onMagnify: ((CGFloat) -> Void)?
        private var monitor: Any?
        private var cachedWindowFrame: CGRect = .null

        /// Installs a local monitor for scroll and magnify events inside the bridge view.
        func installMonitor() {
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) { [weak self] event in
                guard let self, isEnabled, contains(event: event) else { return event }
                return handle(event)
            }
        }

        /// Removes the local monitor if one is installed.
        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }

            monitor = nil
        }

        /// Converts a supported NSEvent into graph actions or returns it unchanged.
        private func handle(_ event: NSEvent) -> NSEvent? {
            switch event.type {
            case .scrollWheel:
                let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 16
                let delta = CGSize(width: -(event.scrollingDeltaX * multiplier), height: -(event.scrollingDeltaY * multiplier))
                guard delta != .zero else { return event }
                onScroll?(delta)
                return nil
            case .magnify:
                guard event.magnification != 0 else { return event }
                onMagnify?(event.magnification)
                return nil
            default:
                return event
            }
        }

        /// Returns whether the event occurred inside the bridge view bounds.
        private func contains(event: NSEvent) -> Bool {
            guard let view, event.window === view.window else { return false }
            updateCachedWindowFrame()
            return cachedWindowFrame.contains(event.locationInWindow)
        }

        /// Stores the bridge's visible frame in window coordinates for reliable event scoping.
        private func updateCachedWindowFrame() {
            guard let view else {
                cachedWindowFrame = .null
                return
            }

            let visibleBounds = view.bounds.intersection(view.visibleRect)
            cachedWindowFrame = view.convert(visibleBounds, to: nil)
        }
    }
}
