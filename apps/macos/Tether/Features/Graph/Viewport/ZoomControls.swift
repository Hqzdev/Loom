import SwiftUI
import UI

struct ZoomControls: View {
    @Binding var zoomScale: CGFloat

    let zoomRange: ClosedRange<CGFloat>
    let onReset: () -> Void
    let palette: AgentTracePalette

    var body: some View {
        HStack(spacing: 8) {
            Button {
                zoomScale = clamped(zoomScale - 0.1)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom Out")

            Slider(value: $zoomScale, in: zoomRange, step: 0.05)
                .frame(width: 92)
                .help("Canvas Zoom")

            Button {
                zoomScale = clamped(zoomScale + 0.1)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom In")

            Button {
                onReset()
            } label: {
                Text("\(Int((zoomScale * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .frame(width: 42)
            }
            .help("Reset Zoom")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(palette.elevated.opacity(0.86), in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        }
        .shadow(color: palette.liquidShade.opacity(0.16), radius: 6, x: 0, y: 3)
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, zoomRange.lowerBound), zoomRange.upperBound)
    }
}
