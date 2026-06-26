import Core
import Networking
import SwiftUI
import UI

struct CometReplaySection: View {
    let node: AgentNode
    let onReplayWithModel: ReplayWithModelAction
    let palette: AgentTracePalette
    @State private var cometConfigured = false
    @State private var loadingCometState = false
    @State private var cometModels: [CometModel] = []
    @State private var selectedCometModelId = ""
    @State private var cometError: String?
    @State private var replayingWithComet = false
    @State private var cometReplayResult: ReplayResult?
    @State private var showingCometDiff = false

    var body: some View {
        Group {
            if cometConfigured {
                Divider()
                    .padding(.vertical, 2)
                section
            }
        }
        .sheet(isPresented: $showingCometDiff) {
            if let cometReplayResult {
                ReplayDiffView(original: node, replay: cometReplayResult, palette: palette)
            }
        }
        .task(id: node.id) {
            await loadCometState()
        }
    }

    private var section: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.violet)
                Text("Cross-model replay")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.text)
                Spacer(minLength: 0)
                if loadingCometState || replayingWithComet {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Picker("", selection: $selectedCometModelId) {
                ForEach(groupedCometModels, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.models) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                }
            }
            .labelsHidden()
            .disabled(cometModels.isEmpty || replayingWithComet)

            ReplayAction(
                title: selectedCometModelId.isEmpty ? "Replay with CometAPI" : "Replay with \(selectedCometModelId)",
                caption: cometError,
                role: .secondary,
                disabled: selectedCometModelId.isEmpty || replayingWithComet,
                captionColor: palette.pinkText,
                palette: palette,
                action: replayWithComet
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var groupedCometModels: [CometModelGroup] {
        let groups = [
            CometModelGroup(title: "GPT", models: cometModels.filter { $0.id.localizedCaseInsensitiveContains("gpt") || $0.provider == "openai" }),
            CometModelGroup(title: "Claude", models: cometModels.filter { $0.id.localizedCaseInsensitiveContains("claude") || $0.provider == "anthropic" }),
            CometModelGroup(title: "Gemini", models: cometModels.filter { $0.id.localizedCaseInsensitiveContains("gemini") || $0.provider == "google" })
        ]
        let groupedIds = Set(groups.flatMap { $0.models }.map(\.id))
        let other = CometModelGroup(title: "Other", models: cometModels.filter { !groupedIds.contains($0.id) })
        return (groups + [other]).filter { !$0.models.isEmpty }
    }

    private func loadCometState() async {
        guard !loadingCometState else { return }

        await MainActor.run {
            loadingCometState = true
            cometError = nil
        }
        do {
            let client = CometAPIClient()
            let status = try await client.cometAPIKeyStatus()
            guard status.configured else {
                await MainActor.run {
                    cometConfigured = false
                    cometModels = []
                    selectedCometModelId = ""
                    loadingCometState = false
                }
                return
            }
            let models = try await client.fetchModels()
            await MainActor.run {
                cometConfigured = true
                cometModels = Array(models.prefix(50))
                if selectedCometModelId.isEmpty || !cometModels.contains(where: { $0.id == selectedCometModelId }) {
                    selectedCometModelId = cometModels.first?.id ?? ""
                }
                loadingCometState = false
            }
        } catch {
            await MainActor.run {
                cometError = error.localizedDescription
                cometConfigured = cometConfigured || KeychainStore.hasValue(.cometAPIKey)
                loadingCometState = false
            }
        }
    }

    private func replayWithComet() {
        guard !replayingWithComet, !selectedCometModelId.isEmpty else { return }

        replayingWithComet = true
        cometError = nil
        Task {
            do {
                let result = try await onReplayWithModel.perform(node, selectedCometModelId)
                await MainActor.run {
                    cometReplayResult = result
                    replayingWithComet = false
                    showingCometDiff = true
                }
            } catch {
                await MainActor.run {
                    cometError = error.localizedDescription
                    replayingWithComet = false
                }
            }
        }
    }
}

private struct CometModelGroup {
    let title: String
    let models: [CometModel]
}

struct ReplayAction: View {
    let title: String
    let caption: String?
    let role: TimeTravelButtonRole
    let disabled: Bool
    var captionColor: Color? = nil
    let palette: AgentTracePalette
    let action: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Text(title)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
            .buttonStyle(TimeTravelButtonStyle(role: role, palette: palette))
            .disabled(disabled)

            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(captionColor ?? Color(hex: 0x888888))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
