import Darwin
import Foundation
import WattcherCore

enum TerminationResult: Equatable {
    case requested
    case refused(String)
}

struct ProcessTerminator {
    private let scanner = SystemScanner()

    func terminate(_ sample: ProcessSample) -> TerminationResult {
        guard !TerminationPolicy.isProtected(
            sample: sample,
            currentUserID: getuid(),
            currentProcessID: getpid()
        ) else {
            return .refused("Wattcher will not terminate system, other-user, or protected processes.")
        }

        let identity: ProcessIdentity
        do {
            guard let current = try scanner.currentIdentity(pid: sample.pid) else {
                return .refused("The process has already exited.")
            }
            identity = current
        } catch {
            return .refused(error.localizedDescription)
        }

        guard identity.pid == sample.pid,
              identity.userID == sample.userID,
              identity.executablePath == sample.executablePath,
              identity.startTimeIdentifier == sample.startTimeIdentifier
        else {
            return .refused("The PID now belongs to a different process, so no signal was sent.")
        }
        guard kill(sample.pid, SIGTERM) == 0 else {
            return .refused(String(cString: strerror(errno)))
        }
        return .requested
    }
}
