import AppKit
import Networking
import SwiftUI
import UI

struct ExtensionsSettingsView: View {
    let palette: AgentTracePalette
    @EnvironmentObject private var preferences: AppPreferences
    @StateObject private var access = WorkspaceAccessStore.shared

    private var codexDirectory: URL {
        access.codexPath.map(URL.init(fileURLWithPath:))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
    }

    private var codexLogsDetected: Bool {
        FileManager.default.fileExists(atPath: codexDirectory.appendingPathComponent("logs_2.sqlite").path)
    }

    var body: some View {
        SettingsPaneScaffold(
            title: "Extensions",
            subtitle: "Connect source adapters for local agent runs on your Mac.",
            palette: palette
        ) {
            cometSection
            codexSection
        }
    }

    private var cometSection: some View {
        SettingsSection("CometAPI", palette: palette) {
            CometAPIKeyRow(palette: palette)
        }
    }

    private var codexSection: some View {
        SettingsSection("Terminal Codex", palette: palette) {
            SettingsToggleRow(
                "Enable Codex source adapter",
                subtitle: "Observe Codex CLI runs from local databases.",
                isOn: $preferences.codexIntegrationEnabled,
                palette: palette
            )

            SettingsValueRow(
                "Local databases",
                subtitle: codexDirectory.path,
                value: access.hasCodexAccess ? (codexLogsDetected ? "Granted" : "Missing DB") : "Not granted",
                palette: palette
            )

            SettingsButtonRow(
                "Codex local log access",
                subtitle: "Grant once so this source adapter can read Terminal Codex logs.",
                buttonTitle: access.hasCodexAccess ? "Change Folder" : "Grant Access",
                systemImage: "folder.badge.gearshape",
                palette: palette
            ) {
                access.requestCodexAccess()
            }

            if access.hasCodexAccess {
                SettingsButtonRow(
                    "Forget Codex access",
                    subtitle: "Remove the saved permission and stop reading this source.",
                    buttonTitle: "Forget",
                    systemImage: "xmark.circle",
                    destructive: true,
                    palette: palette
                ) {
                    access.forgetCodexAccess()
                }
            }
        }
    }
}

private struct CometAPIKeyRow: View {
    let palette: AgentTracePalette
    @State private var apiKey = ""
    @State private var saving = false
    @State private var status: RowStatus = .idle

    enum RowStatus {
        case idle
        case saving
        case success(Int)
        case failure(String)
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("API key")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text)

                Text(statusMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(statusColor)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                SecureField("sk-comet-...", text: $apiKey)
                    .settingsField(palette: palette)
                    .frame(width: 300)
                    .onSubmit(saveAndTest)

                Button {
                    saveAndTest()
                } label: {
                    if saving {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 116, height: 30)
                    } else {
                        Label("Save & Test", systemImage: "checkmark.circle")
                            .frame(width: 116, height: 30)
                    }
                }
                .buttonStyle(SettingsSecondaryButtonStyle(palette: palette))
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving)
            }
        }
        .frame(minHeight: 70)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.borderSoft)
                .frame(height: 1)
        }
    }

    private var statusMessage: String {
        switch status {
        case .idle:
            return "Saved to the local proxy settings database."
        case .saving:
            return "Testing..."
        case let .success(count):
            return "✓ Connected — \(count) models available"
        case let .failure(message):
            return message
        }
    }

    private var statusColor: Color {
        switch status {
        case .success:
            return palette.green
        case .failure:
            return palette.pinkText
        default:
            return palette.textTertiary
        }
    }

    private func saveAndTest() {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !saving else { return }
        saving = true
        status = .saving

        Task {
            do {
                let ok = try await CometAPIClient.testConnection(apiKey: key)
                if ok {
                    let models = try await CometAPIClient.fetchModels()
                    await MainActor.run {
                        status = .success(models.count)
                        saving = false
                    }
                } else {
                    await MainActor.run {
                        status = .failure("No models returned")
                        saving = false
                    }
                }
            } catch {
                await MainActor.run {
                    status = .failure(error.localizedDescription)
                    saving = false
                }
            }
        }
    }
}
