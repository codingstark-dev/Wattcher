public struct ScanGate: Sendable {
    public private(set) var isRunning = false

    public init() {}

    public mutating func begin() -> Bool {
        guard !isRunning else { return false }
        isRunning = true
        return true
    }

    public mutating func end() {
        isRunning = false
    }
}
