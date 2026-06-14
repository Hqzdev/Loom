import Core
import SwiftUI
import UI

struct InspectorPane: View {
    let node: AgentNode?
    @Binding var tab: InspectorTab
    @Binding var responseEdits: [AgentNode.ID: String]
    let palette: AgentTracePalette

    @State private var editing = false
    @State private var draft = ""

    private var responseText: String {
        guard let node else { return "" }
        return responseEdits[node.id] ?? node.response.text
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack(spacing: 9) {
                    if let node {
                        StatusDot(status: node.status, palette: palette)
                        Text(node.stepName)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(palette.text)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        HStack(spacing: 6) {
                            AgentBadge(name: node.agentName, palette: palette)

                            Text(node.model)
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(palette.violet)
                                .lineLimit(1)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(palette.violet.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                                        .stroke(palette.violetBorder, lineWidth: 1)
                                )
                        }
                    } else {
                        Text("Inspector")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)
                    }
                }

                InspectorTabPicker(tab: $tab, palette: palette)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 0)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(palette.border)
                    .frame(height: 1)
            }

            if let node {
                InspectorBody(
                    node: node,
                    tab: tab,
                    responseText: responseText,
                    edited: responseEdits[node.id] != nil,
                    editing: editing,
                    draft: $draft,
                    palette: palette
                )
            } else {
                InspectorEmptyState(palette: palette)
            }

            if let node {
                VStack(spacing: 7) {
                    if editing {
                        Button {
                            responseEdits[node.id] = draft
                            editing = false
                        } label: {
                            Text("Save Mocked Response & Replay")
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                        }
                        .buttonStyle(TimeTravelButtonStyle(active: true, palette: palette))

                        Text("downstream steps will re-run against your edit - cancel")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(palette.textQuaternary)
                            .onTapGesture {
                                editing = false
                            }
                    } else {
                        Button {
                            draft = responseText
                            editing = true
                            tab = .response
                        } label: {
                            Text("Time-Travel - Edit Response")
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                        }
                        .buttonStyle(TimeTravelButtonStyle(active: false, palette: palette))

                        Text("intercept and rewrite this node output, then replay the chain")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(palette.textQuaternary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(palette.panelSecondary.opacity(0.50))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(palette.border)
                        .frame(height: 1)
                }
            }
        }
        .background(palette.panel.opacity(0.54))
        .onChange(of: node?.id) {
            editing = false
            draft = ""
        }
        .onChange(of: tab) {
            editing = false
        }
    }
}

/// Liquid-glass styled segmented control for the inspector sections.
/// A floating glass pill slides between the Prompt / Response / Metadata tabs.
private struct InspectorTabPicker: View {
    @Binding var tab: InspectorTab
    let palette: AgentTracePalette

    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(InspectorTab.allCases) { item in
                let selected = tab == item
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        tab = item
                    }
                } label: {
                    Text(item.title)
                        .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? palette.text : palette.textTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .contentShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
                        .background {
                            if selected {
                                Color.clear
                                    .liquidGlass(
                                        palette: palette,
                                        in: RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous),
                                        tint: palette.glassTintStrong,
                                        interactive: true,
                                        strokeOpacity: 0.82
                                    )
                                    .matchedGeometryEffect(id: "selection", in: pill)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
                .fill(palette.panelSecondary.opacity(0.55))
                .overlay {
                    RoundedRectangle(cornerRadius: palette.panelRadius, style: .continuous)
                        .stroke(palette.glassStrokeSoft, lineWidth: 1)
                }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct InspectorBody: View {
    let node: AgentNode
    let tab: InspectorTab
    let responseText: String
    let edited: Bool
    let editing: Bool
    @Binding var draft: String
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 0) {
            switch tab {
            case .prompt:
                EditorToolbar(
                    title: "request.prompt",
                    chips: [
                        "temp \(node.temperature.map { String(format: "%.1f", $0) } ?? "n/a")",
                        "\(node.tokensIn) tok"
                    ],
                    palette: palette
                )
                CodeView(
                    sections: [
                        CodeSection(label: "system", text: node.prompt.system),
                        CodeSection(label: "user", text: node.prompt.user)
                    ],
                    language: .text,
                    highlightedStatus: nil,
                    palette: palette
                )

            case .response:
                EditorToolbar(
                    title: node.response.language == .json ? "response.json" : "response.txt",
                    chips: responseChips,
                    palette: palette
                )

                if let error = node.error, !editing {
                    ErrorBanner(error: error, palette: palette)
                }

                if editing {
                    TextEditor(text: $draft)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(palette.green)
                        .scrollContentBackground(.hidden)
                        .background(palette.panelSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(palette.amber, lineWidth: 2)
                                .opacity(0.9)
                        )
                } else {
                    CodeView(
                        sections: [CodeSection(label: nil, text: responseText)],
                        language: node.response.language,
                        highlightedStatus: node.status == .error ? .error : nil,
                        palette: palette
                    )
                }

            case .metadata:
                MetadataTable(node: node, edited: edited, palette: palette)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var responseChips: [String] {
        var chips: [String] = []
        if edited {
            chips.append("edited")
        }

        if let error = node.error {
            chips.append(error.code)
        } else if node.status == .running {
            chips.append("LIVE")
        } else {
            chips.append("200 OK")
        }

        return chips
    }
}

private struct EditorToolbar: View {
    let title: String
    let chips: [String]
    let palette: AgentTracePalette

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(palette.textQuaternary)

            Spacer(minLength: 0)

            ForEach(chips, id: \.self) { chip in
                Text(chip)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(chip == "200 OK" ? palette.green : chip == "LIVE" ? palette.amber : chip == "edited" ? palette.amber : palette.textTertiary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(chip == "200 OK" ? palette.greenBackground : chip == "LIVE" ? palette.amber.opacity(0.10) : palette.panel)
                    .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                            .stroke(chip == "200 OK" ? palette.greenDim : chip == "LIVE" ? palette.amber.opacity(0.36) : palette.border, lineWidth: 1)
                    )
            }
        }
        .frame(height: 32)
        .padding(.horizontal, 12)
        .background(palette.panelSecondary)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.borderSoft)
                .frame(height: 1)
        }
    }
}

private struct CodeSection: Hashable {
    let label: String?
    let text: String
}

private struct CodeView: View {
    let sections: [CodeSection]
    let language: ResponseLanguage
    let highlightedStatus: NodeStatus?
    let palette: AgentTracePalette

    private var rows: [CodeRow] {
        var result: [CodeRow] = []
        var lineNumber = 1

        for section in sections {
            if let label = section.label {
                result.append(CodeRow(number: lineNumber, label: label, text: nil))
                lineNumber += 1
            }

            let lines = section.text.isEmpty ? [""] : section.text.components(separatedBy: .newlines)
            for line in lines {
                result.append(CodeRow(number: lineNumber, label: nil, text: line))
                lineNumber += 1
            }
        }

        return result
    }

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    CodeLineView(
                        row: row,
                        language: language,
                        highlightedStatus: highlightedStatus,
                        palette: palette
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(palette.panelSecondary.opacity(0.52))
    }
}

private struct CodeRow: Identifiable {
    let id = UUID()
    let number: Int
    let label: String?
    let text: String?
}

private struct CodeLineView: View {
    let row: CodeRow
    let language: ResponseLanguage
    let highlightedStatus: NodeStatus?
    let palette: AgentTracePalette

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("\(row.number)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(palette.textQuaternary)
                .frame(width: 48, alignment: .trailing)
                .padding(.trailing, 12)
                .padding(.leading, 14)
                .frame(minHeight: 20)
                .background(palette.panel.opacity(0.48))
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(palette.borderSoft)
                        .frame(width: 1)
                }

            if let label = row.label {
                let labelAccent = sectionLabelAccent(for: label)

                HStack(spacing: 8) {
                    Text(label.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(labelAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(labelAccent.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                                .stroke(labelAccent.opacity(0.32), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))

                    Rectangle()
                        .fill(labelAccent.opacity(0.18))
                        .frame(height: 1)
                }
                .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(palette.panel.opacity(0.56))
            } else {
                syntaxText(row.text ?? "")
                    .font(.system(size: 12, design: .monospaced))
                    .lineSpacing(5)
                    .foregroundStyle(highlightedStatus == .error ? palette.pinkText : palette.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
                    .padding(.horizontal, 16)
                    .background(highlightedStatus == .error ? palette.pinkBackground.opacity(0.55) : Color.clear)
                    .overlay(alignment: .leading) {
                        if highlightedStatus == .error {
                            Rectangle()
                                .fill(palette.pink)
                                .frame(width: 3)
                        }
                    }
            }
        }
    }

    private func syntaxText(_ text: String) -> Text {
        guard language == .json else {
            return Text(text.isEmpty ? " " : text)
        }

        return Text(text.isEmpty ? " " : text)
    }

    private func sectionLabelAccent(for label: String) -> Color {
        switch label.lowercased() {
        case "system":
            return palette.violet
        case "user":
            return palette.accent
        case "assistant":
            return palette.green
        default:
            return palette.textTertiary
        }
    }
}

private struct ErrorBanner: View {
    let error: AgentError
    let palette: AgentTracePalette

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Text("x")
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(error.code) - \(error.message)")
                    .font(.system(size: 11.5, weight: .semibold))
                Text(error.detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.textQuaternary)
            }
        }
        .foregroundStyle(palette.pinkText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(palette.pinkBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.pinkDim)
                .frame(height: 1)
        }
    }
}

private struct MetadataTable: View {
    let node: AgentNode
    let edited: Bool
    let palette: AgentTracePalette

    private var rows: [(String, String, Color?)] {
        [
            ("Request ID", node.requestId, nil),
            ("Agent", node.agentName, nil),
            ("Status", node.error?.code ?? node.status.label, palette.color(for: node.status)),
            ("Model", node.model, nil),
            ("Exact Latency", node.latency, node.status == .cached ? palette.cyan : nil),
            ("Tokens In", "\(node.tokensIn)", nil),
            ("Tokens Out", "\(node.tokensOut)", nil),
            ("Cost", node.cost, nil),
            ("Cache Status", node.cacheStatus, node.cacheStatus == "HIT" ? palette.cyan : nil),
            ("Temperature", node.temperature.map { String(format: "%.2f", $0) } ?? "n/a", nil),
            ("Timestamp", node.timestamp, nil),
            ("Mock Override", edited ? "ACTIVE" : "none", edited ? palette.pink : nil)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(rows, id: \.0) { row in
                    HStack(spacing: 16) {
                        Text(row.0)
                            .font(.system(size: 11.5))
                            .foregroundStyle(palette.textTertiary)
                            .frame(width: 150, alignment: .leading)

                        Text(row.1)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(row.2 ?? palette.text)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(palette.borderSoft)
                            .frame(height: 1)
                    }
                }
            }
        }
        .background(palette.panel.opacity(0.52))
    }
}

private struct InspectorEmptyState: View {
    let palette: AgentTracePalette

    var body: some View {
        VStack(spacing: 10) {
            Text("No node selected")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.textTertiary)

            Text("Prompt, response, and metadata will appear here.")
                .font(.system(size: 11.5))
                .foregroundStyle(palette.textQuaternary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.panel.opacity(0.52))
    }
}

private struct TimeTravelButtonStyle: ButtonStyle {
    let active: Bool
    let palette: AgentTracePalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(active ? Color(hex: 0x3a2a00) : Color.white)
            .background(
                LinearGradient(
                    colors: active
                        ? [Color(hex: 0xffd27a), Color(hex: 0xf5b94f)]
                        : [palette.accent, palette.accentTwo, palette.accentThree],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: palette.controlRadius, style: .continuous)
                    .stroke(active ? Color(hex: 0xe0a23f) : palette.accent.opacity(0.22), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}
