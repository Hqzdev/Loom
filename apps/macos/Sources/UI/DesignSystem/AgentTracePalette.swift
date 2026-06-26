import Core
import SwiftUI

public struct AgentTracePalette: Equatable {
    public let light: Bool

    public init(light: Bool) {
        self.light = true
    }

    public var stage: Color { Color(hex: 0xf7f7f8) }
    public var stageGlowOne: Color { Color(hex: 0xfafafa) }
    public var stageGlowTwo: Color { Color(hex: 0xf1f1f3) }
    public var gridLine: Color { Color(hex: 0xe8e8eb) }

    public var paperRadius: CGFloat { 14 }
    public var panelRadius: CGFloat { 10 }
    public var controlRadius: CGFloat { 7 }

    public var window: Color { Color(hex: 0xffffff) }
    public var panel: Color { Color(hex: 0xf8f8f9) }
    public var panelSecondary: Color { Color(hex: 0xefeff1) }
    public var elevated: Color { Color(hex: 0xffffff) }
    public var active: Color { Color(hex: 0xe5e7eb) }
    public var border: Color { Color(hex: 0xd9d9de) }
    public var borderSoft: Color { Color(hex: 0xe9e9ed) }
    public var borderStrong: Color { Color(hex: 0xc9c9d0) }

    public var titleTop: Color { Color.white.opacity(0.82) }
    public var titleBottom: Color { Color(hex: 0xf6f7f9).opacity(0.74) }
    public var paperTop: Color { Color(hex: 0xfafafa).opacity(0.94) }
    public var paperBottom: Color { Color(hex: 0xf1f1f3).opacity(0.86) }
    public var nodeTop: Color { Color(hex: 0xffffff) }
    public var nodeBottom: Color { Color(hex: 0xf7f7f8) }
    public var gridDot: Color { Color.black.opacity(0.05) }
    public var glassTint: Color { Color.white.opacity(0.58) }
    public var glassTintStrong: Color { Color.white.opacity(0.82) }
    public var glassStroke: Color { Color.white.opacity(0.70) }
    public var glassStrokeSoft: Color { Color.black.opacity(0.07) }
    public var glassHighlight: Color { Color.white.opacity(0.82) }
    public var liquidShade: Color { Color(hex: 0x0f172a).opacity(0.08) }

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
