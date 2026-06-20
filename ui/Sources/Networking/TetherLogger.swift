import OSLog

public enum TetherLogger {
    public static let networking = Logger(subsystem: subsystem, category: "networking")
    public static let proxy = Logger(subsystem: subsystem, category: "proxy")
    public static let settings = Logger(subsystem: subsystem, category: "settings")
    public static let codex = Logger(subsystem: subsystem, category: "codex")
    public static let replay = Logger(subsystem: subsystem, category: "replay")

    private static let subsystem = "app.tether.Tether"
}
