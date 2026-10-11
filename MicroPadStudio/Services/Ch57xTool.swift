import Foundation

/// Wraps the bundled `ch57x-keyboard-tool` CLI. Config goes via STDIN (v1.7.0).
/// Stateless struct → safe to call from background threads; the UI thread must
/// never run these directly (upload takes seconds and would freeze the app).
struct Ch57xTool {
    enum ToolError: LocalizedError {
        case binaryNotFound
        case launchFailed(String)
        case failed(exit: Int32, output: String)
        case timedOut(String, seconds: Int)
        case busy

        var errorDescription: String? {
            switch self {
            case .binaryNotFound:
                return "ch57x-keyboard-tool binary not found (expected in app bundle Resources or ~/.local/bin)."
            case .launchFailed(let msg): return "Could not launch tool: \(msg)"
            case .failed(let code, let output):
                return "Tool exited with \(code):\n\(output)"
            case .timedOut(let what, let secs):
                return "\(what) timed out after \(secs)s. If this was an upload, the pad's USB interface may be wedged — unplug the pad, wait 2 s, replug, retry."
            case .busy:
                return "Another upload is already in progress (MicroPad Studio or MicroPad Menu). Wait for it to finish."
            }
        }
    }

    /// Candidate lookup order: MICROPAD_TOOL_PATH (tests only — lets selftests run a
    /// fake tool instead of flashing the real pad), bundled resource, ~/.local/bin.
    static func binaryURL() -> URL? {
        var candidates: [URL] = []
        if let override = ProcessInfo.processInfo.environment["MICROPAD_TOOL_PATH"] {
            candidates.append(URL(fileURLWithPath: override))
        }
        if let res = Bundle.main.resourceURL?.appendingPathComponent("ch57x-keyboard-tool") {
            candidates.append(res)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        candidates.append(home.appendingPathComponent(".local/bin/ch57x-keyboard-tool"))
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// Runs a subcommand with YAML on stdin under a hard deadline. Blocking —
    /// call off the main thread. SIGTERM at `timeout`, SIGKILL 3 s later, so a
    /// hung tool can never freeze the caller forever.
    private func run(subcommand: String, stdin yaml: String, timeout: TimeInterval) throws -> (String, Int32) {
        guard let url = Self.binaryURL() else { throw ToolError.binaryNotFound }
        let proc = Process()
        proc.executableURL = url
        proc.arguments = [subcommand]
        let inPipe = Pipe()
        let outPipe = Pipe()
        proc.standardInput = inPipe
        proc.standardOutput = outPipe
        proc.standardError = outPipe
        let finished = DispatchSemaphore(value: 0)
        let timedOut = TimeoutFlag()
        proc.terminationHandler = { _ in finished.signal() }
        do {
            try proc.run()
        } catch {
            throw ToolError.launchFailed(error.localizedDescription)
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            if proc.isRunning {
                timedOut.set()
                proc.terminate()
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                    if proc.isRunning { kill(proc.processIdentifier, SIGKILL) }
                }
            }
        }
        // Write stdin fully (small payload; safe to do before reading).
        inPipe.fileHandleForWriting.write(Data(yaml.utf8))
        inPipe.fileHandleForWriting.closeFile()
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        finished.wait()
        if timedOut.get() { throw ToolError.timedOut(subcommand, seconds: Int(timeout)) }
        let output = String(data: data, encoding: .utf8) ?? ""
        return (output, proc.terminationStatus)
    }

    /// Throws with the tool's message when validation fails.
    func validate(_ yaml: String) throws {
        let (output, code) = try run(subcommand: "validate", stdin: yaml, timeout: 15)
        if code != 0 { throw ToolError.failed(exit: code, output: output.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    /// Uploads mapping to the connected pad. DESTRUCTIVE on-device.
    /// Serialised across processes with an flock so Studio and the menu helper can
    /// never drive the USB write at the same time.
    func upload(_ yaml: String) throws {
        let fd = open(Self.lockURL().path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { throw ToolError.launchFailed("cannot open upload lock") }
        defer { close(fd) }   // closing releases the lock
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw ToolError.busy }
        let (output, code) = try run(subcommand: "upload", stdin: yaml, timeout: 120)
        if code != 0 { throw ToolError.failed(exit: code, output: output.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    static func lockURL() -> URL {
        let dir = ConfigLibrary.defaultDir().deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("upload.lock")
    }

    /// Raw output of show-keys (for the M2 action picker).
    func showKeys() throws -> String {
        try run(subcommand: "show-keys", stdin: "", timeout: 15).0
    }
}

/// Lock-guarded bool so the timer thread can flag a timeout for the waiting caller.
private final class TimeoutFlag: @unchecked Sendable {
    private var value = false
    private let lock = NSLock()
    func set() { lock.lock(); value = true; lock.unlock() }
    func get() -> Bool { lock.lock(); defer { lock.unlock() }; return value }
}
