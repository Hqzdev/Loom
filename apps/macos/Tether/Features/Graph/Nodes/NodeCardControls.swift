import Core
import SwiftUI
import UI

struct NodeAnchorMarkers: View {
    let palette: AgentTracePalette

    var body: some View {
        GeometryReader { geometry in
            ForEach([NodeAnchorSide.top, .bottom], id: \.self) { side in
                Circle()
                    .fill(palette.window.opacity(0.96))
                    .frame(width: 10, height: 10)
                    .overlay {
                        Circle()
                            .stroke(palette.borderStrong, lineWidth: 1.4)
                    }
                    .position(side.markerPosition(in: geometry.size))
            }
        }
        .allowsHitTesting(false)
    }
}

struct ProgressBar: View {
    let value: Double
    let status: NodeStatus
    let palette: AgentTracePalette

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(palette.panelSecondary.opacity(0.86))

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [palette.dimColor(for: status), palette.color(for: status)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 3)
    }
}
