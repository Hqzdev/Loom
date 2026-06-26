import SwiftUI

/// Reveal animation used by welcome screen sections.
struct WelcomeRevealModifier: ViewModifier {
    let isVisible: Bool
    let delay: Double

    /// Applies opacity and vertical offset animation for first-run welcome content.
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(.easeOut(duration: 0.4).delay(delay), value: isVisible)
    }
}

extension View {
    /// Applies the standard welcome reveal animation.
    func welcomeReveal(_ isVisible: Bool, delay: Double) -> some View {
        modifier(WelcomeRevealModifier(isVisible: isVisible, delay: delay))
    }
}
