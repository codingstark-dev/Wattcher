public enum TerminationPolicy {
    public static func isProtected(
        sample: ProcessSample,
        currentUserID: UInt32,
        currentProcessID: Int32
    ) -> Bool {
        if sample.pid <= 1 || sample.pid == currentProcessID || sample.userID != currentUserID {
            return true
        }
        let protectedNames: Set<String> = [
            "kernel_task", "launchd", "loginwindow", "WindowServer",
        ]
        if protectedNames.contains(sample.name) { return true }
        let protectedPrefixes = ["/System/", "/usr/libexec/", "/usr/sbin/", "/sbin/"]
        return protectedPrefixes.contains { sample.executablePath.hasPrefix($0) }
    }
}
