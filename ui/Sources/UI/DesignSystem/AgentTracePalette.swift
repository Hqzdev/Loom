import Core
import SwiftUI

public struct AgentTracePalette {
    public let light: Bool

    public init(light: Bool) {
        self.light = light
    }

    public var stage: Color { Color.white }
    public var stageGlowOne: Color { Color(hex: 0xfafafa) }
    public var stageGlowTwo: Color { Color(hex: 0xf4f4f5) }
    public var gridLine: Color { Color(hex: 0xf0f0f0) }

    public var paperRadius: CGFloat { 28 }
    public var panelRadius: CGFloat { 18 }
    public var controlRadius: CGFloat { panelRadius }

    public var window: Color { Color.white }
    public var panel: Color { Color(hex: 0xfafafa) }
    public var panelSecondary: Color { Color(hex: 0xf4f4f5) }
    public var elevated: Color { Color.white }
    public var active: Color { Color(hex: 0xe4e4e7) }
    public var border: Color { Color(hex: 0xe4e4e7) }
    public var borderSoft: Color { Color(hex: 0xeeeeef) }
    public var borderStrong: Color { Color(hex: 0xd4d4d8) }

    public var titleTop: Color { Color.white.opacity(0.88) }
    public var titleBottom: Color { Color(hex: 0xf8fafc).opacity(0.76) }
    public var paperTop: Color { Color(hex: 0xfafafa).opacity(0.94) }
    public var paperBottom: Color { Color(hex: 0xf4f4f5).opacity(0.86) }
    public var nodeTop: Color { Color.white }
    public var nodeBottom: Color { Color(hex: 0xfafafa) }
    public var gridDot: Color { Color.black.opacity(0.055) }
    public var glassTint: Color { Color.white.opacity(0.74) }
    public var glassTintStrong: Color { Color.white.opacity(0.88) }
    public var glassStroke: Color { Color.white.opacity(0.90) }
    public var glassStrokeSoft: Color { Color.black.opacity(0.08) }
    public var glassHighlight: Color { Color.white.opacity(0.96) }
    public var liquidShade: Color { Color(hex: 0x0f172a).opacity(0.10) }

    public var text: Color { Color(hex: 0x18181b) }
    public var textSecondary: Color { Color(hex: 0x3f3f46) }
    public var textTertiary: Color { Color(hex: 0x71717a) }
    public var textQuaternary: Color { Color(hex: 0xa1a1aa) }

    public var green: Color { Color(hex: 0x10b981) }
    public var greenDim: Color { Color(hex: 0xa7f3d0) }
    public var greenBackground: Color { green.opacity(0.10) }
    public var cyan: Color { Color(hex: 0x0284c7) }
    public var cyanDim: Color { Color(hex: 0xbae6fd) }
    public var cyanBackground: Color { cyan.opacity(0.10) }
    public var pink: Color { Color(hex: 0xdb2777) }
    public var pinkDim: Color { Color(hex: 0xfbcfe8) }
    public var pinkBackground: Color { pink.opacity(0.10) }
    public var pinkText: Color { Color(hex: 0xbe185d) }
    public var violet: Color { Color(hex: 0x7c3aed) }
    public var violetBorder: Color { Color(hex: 0xddd6fe) }
    public var amber: Color { Color(hex: 0xd97706) }
    public var accent: Color { Color(hex: 0x4f46e5) }
    public var accentTwo: Color { Color(hex: 0x9333ea) }
    public var accentThree: Color { Color(hex: 0xec4899) }
    public var accentBackground: Color { accent.opacity(0.10) }

    public func color(for status: NodeStatus) -> Color {
        switch status {
        case .success:
            return green
        case .cached:
            return cyan
        case .running:
            return amber
        case .error:
            return pink
        }
    }

    public func dimColor(for status: NodeStatus) -> Color {
        switch status {
        case .success:
            return greenDim
        case .cached:
            return cyanDim
        case .running:
            return amber.opacity(0.36)
        case .error:
            return pinkDim
        }
    }

    public func background(for status: NodeStatus) -> Color {
        switch status {
        case .success:
            return greenBackground
        case .cached:
            return cyanBackground
        case .running:
            return amber.opacity(0.10)
        case .error:
            return pinkBackground
        }
    }
}

public extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

public struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let palette: AgentTracePalette
    let shape: S
    let tint: Color?
    let interactive: Bool
    let strokeOpacity: Double

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

public extension View {
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
