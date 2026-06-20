import Foundation
import Networking
import OSLog

extension ProxySettingsView {
    /// Persists validated proxy settings and restarts the local helper.
    func saveAndRestart() {
        do {
            let settings = try validatedSettings()
            ProxySettingsStore.save(settings)
            saveProviderKeys()
            LocalProxyLauncher.shared.restart()
            footerMessage = "Requires proxy restart"
            footerMessageIsError = false
        } catch {
            TetherLogger.settings.error("proxy_settings_save_failed: \(error.localizedDescription, privacy: .public)")
            footerMessage = error.localizedDescription
            footerMessageIsError = true
        }
    }

    /// Clears cached proxy responses through the local API.
    func clearCache() {
        Task {
            do {
                try await TraceAPIClient().clearCache()
                footerMessage = "Cache cleared"
                footerMessageIsError = false
            } catch {
                TetherLogger.settings.error("cache_clear_failed: \(error.localizedDescription, privacy: .public)")
                footerMessage = error.localizedDescription
                footerMessageIsError = true
            }
        }
    }

    /// Validates the proxy form and returns a persistable settings value.
    func validatedSettings() throws -> ProxySettings {
        let trimmedPort = portText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = Int(trimmedPort), (1...65535).contains(port) else {
            throw ProxySettingsValidationError.invalidPort
        }

        let openAIURL = try normalizedURL(openAIUpstreamURL, label: "OpenAI")
        let anthropicURL = try normalizedURL(anthropicUpstreamURL, label: "Anthropic")

        return ProxySettings(
            port: port,
            openAIUpstreamURL: openAIURL,
            anthropicUpstreamURL: anthropicURL,
            localCacheEnabled: localCacheEnabled
        )
    }

    /// Normalizes and validates an upstream URL field.
    func normalizedURL(_ value: String, label: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil
        else {
            throw ProxySettingsValidationError.invalidURL(label)
        }

        return trimmed
    }

    /// Stores entered provider keys and clears plaintext field state.
    private func saveProviderKeys() {
        if !openAIKey.isEmpty {
            KeychainStore.save(.openAIAPIKey, value: openAIKey)
            openAIKey = ""
            openAIKeyStored = true
        }
        if !anthropicKey.isEmpty {
            KeychainStore.save(.anthropicAPIKey, value: anthropicKey)
            anthropicKey = ""
            anthropicKeyStored = true
        }
        if !cometAPIKey.isEmpty {
            let value = cometAPIKey
            KeychainStore.save(.cometAPIKey, value: value)
            cometAPIKey = ""
            cometAPIKeyStored = true
            Task {
                await syncCometAPIKey(value)
            }
        }
    }

    /// Tests the CometAPI key by syncing it to the proxy and loading the model catalog.
    func testCometAPIConnection() {
        let key = cometAPIKey.isEmpty ? KeychainStore.read(.cometAPIKey) ?? "" : cometAPIKey
        guard !key.isEmpty else {
            cometAPIStatus = "Enter a CometAPI key first"
            cometAPIStatusIsError = true
            return
        }

        testingCometAPI = true
        cometAPIStatus = "Testing..."
        cometAPIStatusIsError = false
        Task {
            do {
                let connected = try await CometAPIClient.testConnection(apiKey: key)
                await MainActor.run {
                    if connected {
                        KeychainStore.save(.cometAPIKey, value: key)
                        cometAPIKey = ""
                        cometAPIKeyStored = true
                        cometAPIStatus = "Connected: 500+ models available"
                        cometAPIStatusIsError = false
                    } else {
                        cometAPIStatus = "No models returned"
                        cometAPIStatusIsError = true
                    }
                    testingCometAPI = false
                }
            } catch {
                await MainActor.run {
                    TetherLogger.settings.error("cometapi_connection_test_failed: \(error.localizedDescription, privacy: .public)")
                    cometAPIStatus = error.localizedDescription
                    cometAPIStatusIsError = true
                    testingCometAPI = false
                }
            }
        }
    }

    /// Persists the CometAPI key to the local proxy without exposing it in replay calls.
    private func syncCometAPIKey(_ key: String) async {
        do {
            try await CometAPIClient().saveAPIKey(key)
        } catch {
            await MainActor.run {
                TetherLogger.settings.error("cometapi_key_sync_failed: \(error.localizedDescription, privacy: .public)")
                cometAPIStatus = error.localizedDescription
                cometAPIStatusIsError = true
            }
        }
    }
}
