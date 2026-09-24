import Foundation

/// What `molt` was asked to do. Extra words after a known command are rejected
/// so a typo does not silently install or evict.
public enum MoltCommand: Equatable {
    case run
    case install
    case uninstall
    case status
    case help

    public static func parse(_ args: [String]) -> MoltCommand {
        switch args.first {
        case nil, "run":
            return args.count <= 1 ? .run : .help
        case "install" where args.count == 1:
            return .install
        case "uninstall" where args.count == 1:
            return .uninstall
        case "status" where args.count == 1:
            return .status
        case "help", "-h", "--help":
            return .help
        default:
            return .help
        }
    }
}

/// LaunchAgent plist. Pure so the XML can be tested without touching launchd.
public enum AgentPlist {
    /// Stable label. The earlier prototype used `local.icloud-keep-remote`.
    public static let label = "com.lebyy.molt"

    /// How often a loaded agent wakes up and drops local copies.
    public static let intervalSeconds = 180

    public static func render(binary: String, interval: Int = intervalSeconds) -> String {
        let path = xml(binary)
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>\(label)</string>
          <key>ProgramArguments</key>
          <array>
            <string>\(path)</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
          <key>StartInterval</key>
          <integer>\(interval)</integer>
        </dict>
        </plist>
        """
    }

    private static func xml(_ raw: String) -> String {
        raw.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

/// Where molt keeps its copy of the binary and the log. Home-relative so the
/// same binary works for whoever installs it.
public enum MoltPaths {
    public static let supportName = "molt"
    public static let binaryName = "molt"
    public static let logName = "molt.log"

    public static func supportDirectory(home: URL) -> URL {
        home.appendingPathComponent("Library/Application Support/\(supportName)", isDirectory: true)
    }

    public static func installedBinary(home: URL) -> URL {
        supportDirectory(home: home).appendingPathComponent(binaryName)
    }

    public static func logFile(home: URL) -> URL {
        supportDirectory(home: home).appendingPathComponent(logName)
    }

    public static func agentPlist(home: URL) -> URL {
        home.appendingPathComponent("Library/LaunchAgents/\(AgentPlist.label).plist")
    }

    /// iCloud Drive's on-disk root. Top-level items here are what a pass releases.
    public static func iCloudDrive(home: URL) -> URL {
        home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
    }
}

/// Append-only log that sheds its own oldest bytes. A pass every three minutes
/// would otherwise grow this file forever.
public enum MoltLog {
    public static let maxBytes = 256_000
    public static let keepBytes = 64_000

    public static func append(_ message: String, to url: URL, now: Date = Date()) {
        let folder = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: now)
        let line = Data((stamp + " " + message + "\n").utf8)
        let prior = (try? Data(contentsOf: url)) ?? Data()
        var combined = prior + line
        if combined.count > maxBytes {
            combined = Data(combined.suffix(keepBytes))
        }
        try? combined.write(to: url)
    }
}
