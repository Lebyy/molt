import Foundation
import MoltCore

/// molt
///
/// Local copies of iCloud Drive files leave the Mac after you close them.
/// The file in iCloud is not deleted. Opening it downloads it again.
///
/// ```
/// molt              release local copies once
/// molt install      do that every 3 minutes, including at login
/// molt uninstall    stop the agent
/// molt status       is the agent loaded, and what did the last pass say
/// molt help
/// ```
///
/// Install once asks macOS for iCloud Drive access. Allow that prompt.
/// The agent then runs this same binary from Application Support, so later
/// rebuilds in a git checkout do not change what launchd is running until
/// you install again.
///
/// A pass only names the top level of iCloud Drive (your folders there).
/// Asking File Provider for every nested file, one at a time, stalls.
/// Evicting a folder tells the daemon to drop the local copies inside it.
enum MoltCLI {
    static func main(_ args: [String]) -> Int32 {
        switch MoltCommand.parse(args) {
        case .run:
            return evict()
        case .install:
            return install()
        case .uninstall:
            return uninstall()
        case .status:
            return status()
        case .help:
            print(helpText)
            return args.isEmpty || args == ["help"] || args == ["-h"] || args == ["--help"] ? 0 : 2
        }
    }

    /// Help is success. An unknown command is still help text, with a failure code.
    private static let helpText = """
    molt — local iCloud copies leave after you close the file

    The copy in iCloud stays. Open a file and macOS downloads it again.
    About three minutes after you are done, molt drops the local copy.

    USAGE
      molt              Release local copies once
      molt install      Keep doing that at login and every 3 minutes
      molt uninstall    Stop and remove the login agent
      molt status       Show whether the agent is loaded
      molt help

    Install copies this binary into ~/Library/Application Support/molt
    and turns on Optimize Mac Storage, which is what makes files download
    only when you open them.

    Only the top level of iCloud Drive is named. Photos, and Desktop or
    Documents when they are not in iCloud Drive, are left alone.
    """

    /// One pass. A folder that is open, or not an iCloud item, is kept and logged.
    private static func evict() -> Int32 {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let root = MoltPaths.iCloudDrive(home: home)
        let logURL = MoltPaths.logFile(home: home)

        func note(_ message: String) {
            MoltLog.append(message, to: logURL)
            print(message)
        }

        guard FileManager.default.fileExists(atPath: root.path) else {
            note("iCloud Drive folder is missing")
            return 1
        }

        let children: [URL]
        do {
            children = try FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        } catch {
            note("cannot list iCloud Drive: \(error.localizedDescription)")
            return 1
        }

        if children.isEmpty {
            note("iCloud Drive has no top-level items")
            return 0
        }

        var evicted = 0
        var kept = 0
        for url in children {
            do {
                // Removes the local bytes. The iCloud file stays.
                try FileManager.default.evictUbiquitousItem(at: url)
                evicted += 1
                note("evicted \(url.lastPathComponent)")
            } catch {
                kept += 1
                note("kept \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        note("done evicted=\(evicted) kept=\(kept)")
        return 0
    }

    /// Copy the binary we are running, sign it, and hand it to launchd.
    /// Signing matters: macOS remembers iCloud permission per binary.
    private static func install() -> Int32 {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let support = MoltPaths.supportDirectory(home: home)
        let destination = MoltPaths.installedBinary(home: home)
        let agent = MoltPaths.agentPlist(home: home)

        do {
            try fm.createDirectory(at: support, withIntermediateDirectories: true)
            try fm.createDirectory(at: agent.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            fputs("could not create support folders: \(error.localizedDescription)\n", stderr)
            return 1
        }

        let source = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        if source.path != destination.path {
            if fm.fileExists(atPath: destination.path) {
                try? fm.removeItem(at: destination)
            }
            do {
                try fm.copyItem(at: source, to: destination)
            } catch {
                fputs("could not copy molt: \(error.localizedDescription)\n", stderr)
                return 1
            }
        }

        guard run("/usr/bin/codesign", ["-s", "-", "--force", destination.path]) == 0 else {
            fputs("codesign failed\n", stderr)
            return 1
        }

        let xml = AgentPlist.render(binary: destination.path)
        do {
            try xml.write(to: agent, atomically: true, encoding: .utf8)
        } catch {
            fputs("could not write launch agent: \(error.localizedDescription)\n", stderr)
            return 1
        }

        let uid = getuid()
        // Replace a previous copy, and the prototype agent from before this repo.
        _ = run("/bin/launchctl", ["bootout", "gui/\(uid)/\(AgentPlist.label)"])
        _ = run("/bin/launchctl", ["bootout", "gui/\(uid)/local.icloud-keep-remote"])
        guard run("/bin/launchctl", ["bootstrap", "gui/\(uid)", agent.path]) == 0 else {
            fputs("launchctl bootstrap failed\n", stderr)
            return 1
        }

        // Download-on-open. Without this, macOS keeps full copies anyway.
        _ = run("/usr/bin/defaults", ["write", "com.apple.bird", "optimize-storage", "-bool", "true"])

        print("Installed. Local copies drop about every 3 minutes.")
        print("If macOS asks for iCloud Drive access, allow it.")
        print("Log: \(MoltPaths.logFile(home: home).path)")
        return 0
    }

    private static func uninstall() -> Int32 {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let uid = getuid()
        _ = run("/bin/launchctl", ["bootout", "gui/\(uid)/\(AgentPlist.label)"])
        let agent = MoltPaths.agentPlist(home: home)
        try? FileManager.default.removeItem(at: agent)
        print("Stopped. The log is still at \(MoltPaths.logFile(home: home).path)")
        return 0
    }

    private static func status() -> Int32 {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let uid = getuid()
        let loaded = run("/bin/launchctl", ["print", "gui/\(uid)/\(AgentPlist.label)"]) == 0
        print(loaded ? "agent: loaded" : "agent: not loaded")
        let logURL = MoltPaths.logFile(home: home)
        guard let text = try? String(contentsOf: logURL, encoding: .utf8) else {
            print("log: none yet")
            return 0
        }
        print("log:")
        for line in text.split(separator: "\n").suffix(8) {
            print(line)
        }
        return 0
    }

    /// Exit status of a short system tool. Output is discarded so a chatty
    /// `launchctl print` cannot fill the pipe and stall.
    @discardableResult
    private static func run(_ executable: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return 1
        }
        process.waitUntilExit()
        return process.terminationStatus
    }
}

exit(MoltCLI.main(Array(CommandLine.arguments.dropFirst())))
