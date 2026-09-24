import Foundation
import MoltCore

/// Stand-in for XCTest. The command line tools on a Mac do not ship XCTest,
/// and this has to compile with zero warnings there.
func check(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL \(message)\n", stderr)
        exit(1)
    }
}

check(MoltCommand.parse([]) == .run, "empty args run once")
check(MoltCommand.parse(["run"]) == .run, "run")
check(MoltCommand.parse(["install"]) == .install, "install")
check(MoltCommand.parse(["uninstall"]) == .uninstall, "uninstall")
check(MoltCommand.parse(["status"]) == .status, "status")
check(MoltCommand.parse(["help"]) == .help, "help")
check(MoltCommand.parse(["-h"]) == .help, "-h")
check(MoltCommand.parse(["--help"]) == .help, "--help")
check(MoltCommand.parse(["install", "please"]) == .help, "extra words")
check(MoltCommand.parse(["nope"]) == .help, "unknown")

let xml = AgentPlist.render(binary: "/tmp/molt & sons", interval: 180)
check(xml.contains("<string>\(AgentPlist.label)</string>"), "label")
check(xml.contains("<integer>180</integer>"), "interval")
check(xml.contains("/tmp/molt &amp; sons"), "escaped path")
check(xml.contains("<key>RunAtLoad</key>"), "run at load")

let url = FileManager.default.temporaryDirectory
    .appendingPathComponent("molt-log-test-\(UUID().uuidString).log")
defer { try? FileManager.default.removeItem(at: url) }
let block = String(repeating: "x", count: 10_000)
for _ in 0..<40 {
    MoltLog.append(block, to: url, now: Date(timeIntervalSince1970: 0))
}
let written = (try? Data(contentsOf: url)) ?? Data()
check(written.count <= MoltLog.maxBytes, "log capped")
check(!written.isEmpty, "log written")

print("ok")
