import SwiftUI

/// View modifier that applies Tether's light liquid-glass panel treatment.
public struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let palette: AgentTracePalette
    let shape: S
    let tint: Color?
    let interactive: Bool
    let strokeOpacity: Double

    /// Renders layered tint, stroke, highlight, and shadow effects around content.
    public func body(content: Content) -> some View {
        content
            .background((tint ?? palette.glassTint), in: shape)
            .overlay {
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                palette.glassHighlight.opacity(strokeOpacity),
                                palette.glassStroke.opacity(strokeOpacity * 0.72),
                                palette.glassStrokeSoft.opacity(strokeOpacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .overlay(alignment: .topLeading) {
                shape
                    .stroke(palette.glassHighlight.opacity(strokeOpacity * 0.32), lineWidth: 0.6)
                    .blur(radius: 0.2)
                    .padding(1)
            }
            .shadow(color: palette.liquidShade.opacity(0.42), radius: 10, x: 0, y: 5)
    }
}

/// Convenience modifiers for applying the shared liquid-glass treatment.
public extension View {
    /// Applies a liquid-glass treatment inside an explicit shape.
    func liquidGlass<S: Shape>(
        palette: AgentTracePalette,
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false,
        strokeOpacity: Double = 1
    ) -> some View {
        modifier(
            LiquidGlassModifier(
                palette: palette,
                shape: shape,
                tint: tint,
                interactive: interactive,
                strokeOpacity: strokeOpacity
            )
        )
    }

    /// Applies a rounded-rectangle liquid-glass treatment.
    func liquidGlass(
        palette: AgentTracePalette,
        cornerRadius: CGFloat,
        tint: Color? = nil,
        interactive: Bool = false,
        strokeOpacity: Double = 1
    ) -> some View {
        liquidGlass(
            palette: palette,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            tint: tint,
            interactive: interactive,
            strokeOpacity: strokeOpacity
        )
    }
}
