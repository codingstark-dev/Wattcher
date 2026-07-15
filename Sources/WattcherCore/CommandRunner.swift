import Foundation

enum CommandRunner {
    static func run(
        path: String,
        arguments: [String],
        acceptedStatuses: Set<Int32>,
        timeout: TimeInterval = 10,
        terminationGrace: TimeInterval = 1
    ) async throws -> String {
        try await Task.detached(priority: .utility) {
            try runSynchronously(
                path: path,
                arguments: arguments,
                acceptedStatuses: acceptedStatuses,
                timeout: timeout,
                terminationGrace: terminationGrace
            )
        }.value
    }

    private static func runSynchronously(
        path: String,
        arguments: [String],
        acceptedStatuses: Set<Int32>,
        timeout: TimeInterval,
        terminationGrace: TimeInterval
    ) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()

        let timeoutState = ProcessTimeout()
        let timeoutWork = DispatchWorkItem {
            timeoutState.markFired()
            guard process.isRunning else {
                outputPipe.fileHandleForReading.closeFile()
                return
            }
            process.terminate()
            DispatchQueue.global(qos: .utility).asyncAfter(
                deadline: .now() + terminationGrace
            ) {
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }
                outputPipe.fileHandleForReading.closeFile()
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + timeout,
            execute: timeoutWork
        )
        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeoutWork.cancel()

        if timeoutState.didFire {
            throw ScanError.timedOut(path: path)
        }
        guard acceptedStatuses.contains(process.terminationStatus) else {
            throw ScanError.commandFailed(
                path: path,
                status: process.terminationStatus,
                message: String(decoding: output, as: UTF8.self)
            )
        }
        return String(decoding: output, as: UTF8.self)
    }
}

private final class ProcessTimeout: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false

    var didFire: Bool {
        lock.withLock { fired }
    }

    func markFired() {
        lock.withLock { fired = true }
    }
}
