import Foundation

public enum PortFilter {
    private static let developmentNames = [
        "astro", "bun", "cargo", "deno", "docker", "go", "java", "node",
        "php", "python", "rails", "ruby", "swift", "vite",
    ]

    public static func filtered(
        _ processes: [ProcessSample],
        query: String,
        showAll: Bool
    ) -> [ProcessSample] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return processes
            .filter { !$0.ports.isEmpty }
            .filter { showAll || isDevelopmentListener($0) }
            .filter { normalizedQuery.isEmpty || searchText(for: $0).contains(normalizedQuery) }
            .sorted { lhs, rhs in
                let lhsPort = lhs.ports.map(\.port).min() ?? .max
                let rhsPort = rhs.ports.map(\.port).min() ?? .max
                if lhsPort != rhsPort { return lhsPort < rhsPort }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    public static func isDevelopmentListener(_ process: ProcessSample) -> Bool {
        let identity = "\(process.name) \(process.executablePath)".lowercased()
        if developmentNames.contains(where: identity.contains) { return true }
        return process.ports.contains { $0.isLoopback && $0.port >= 1_024 }
    }

    private static func searchText(for process: ProcessSample) -> String {
        let ports = process.ports.flatMap { [String($0.port), $0.address, $0.displayName] }
        return ([
            process.name,
            process.executablePath,
            String(process.pid),
            process.origin.label,
        ] + ports).joined(separator: " ").lowercased()
    }
}
