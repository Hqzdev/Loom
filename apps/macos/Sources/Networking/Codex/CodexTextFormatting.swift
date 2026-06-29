import Foundation

extension CodexLogObserver {
    /// Appends a paragraph block with spacing suitable for inspector display.
    nonisolated static func appendBlock(_ block: String, to text: String) -> String {
        guard !text.isEmpty else { return block }
        return "\(text)\n\n\(block)"
    }

    /// Returns the first line from a potentially multi-line value.
    nonisolated static func firstLine(_ value: String) -> String {
        value
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? value
    }

    /// Truncates text while preserving a visible ellipsis for long local log values.
    nonisolated static func truncate(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return "\(value.prefix(limit - 1))..."
    }

    /// Shortens provider-style ids for compact graph labels.
    nonisolated static func shortId(_ value: String) -> String {
        if let suffix = value.split(separator: "_").last {
            return String(suffix.prefix(12))
        }

        return String(value.prefix(12))
    }

    /// Formats latency for inspector and graph labels.
    nonisolated static func formatLatency(milliseconds: Int) -> String {
        if milliseconds >= 1000 {
            return String(format: "%.2fs", Double(milliseconds) / 1000.0)
        }

        return "\(milliseconds)ms"
    }

    /// Formats a Unix timestamp into a compact clock string.
    nonisolated static func formatClock(seconds: Int) -> String {
        guard seconds > 0 else { return "--:--:--" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(seconds)))
    }

    /// Quotes strings for the small SQLite queries against local agent logs.
    nonisolated static func sqlQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "''"))'"
    }
}
