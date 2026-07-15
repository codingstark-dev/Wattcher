import Foundation

struct LaunchOriginScanner: Sendable {
    private struct EntryMap {
        var agents = Set<String>()
        var daemons = Set<String>()
    }

    private let entries: EntryMap

    init() {
        entries = Self.loadEntries()
    }

    init(agentPaths: Set<String>, daemonPaths: Set<String>) {
        entries = EntryMap(agents: agentPaths, daemons: daemonPaths)
    }

    func classify(path: String, parentPID: Int32) -> LaunchOrigin {
        if path.hasPrefix("/System/") || path.hasPrefix("/usr/libexec/") {
            return .system
        }
        if entries.agents.contains(path) { return .launchAgent }
        if entries.daemons.contains(path) { return .launchDaemon }
        if path.contains(".app/Contents/MacOS/") {
            return .foregroundApp
        }
        return parentPID == 1 ? .backgroundProcess : .userProcess
    }

    private static func loadEntries() -> EntryMap {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let agentPaths = ["\(home)/Library/LaunchAgents", "/Library/LaunchAgents"]
        let daemonPaths = ["/Library/LaunchDaemons"]
        return EntryMap(
            agents: executablePaths(in: agentPaths),
            daemons: executablePaths(in: daemonPaths)
        )
    }

    private static func executablePaths(in directories: [String]) -> Set<String> {
        let resourceKeys: Set<URLResourceKey> = [
            .fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey,
        ]
        var paths = Set<String>()
        for directory in directories {
            let url = URL(fileURLWithPath: directory, isDirectory: true)
            let files = (try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            )) ?? []
            for file in files where file.pathExtension == "plist" {
                guard let values = try? file.resourceValues(forKeys: resourceKeys),
                      values.isRegularFile == true,
                      values.isSymbolicLink != true,
                      let size = values.fileSize,
                      size <= 1_048_576,
                      let data = try? Data(contentsOf: file, options: [.mappedIfSafe]),
                      let object = try? PropertyListSerialization.propertyList(from: data, format: nil),
                      let dictionary = object as? [String: Any]
                else { continue }

                let program = dictionary["Program"] as? String
                let arguments = dictionary["ProgramArguments"] as? [String]
                if let executable = program ?? arguments?.first,
                   executable.hasPrefix("/") {
                    paths.insert(URL(fileURLWithPath: executable).standardized.path)
                }
            }
        }
        return paths
    }
}
