import Foundation

/// Wraps the bundled `ch57x-keyboard-tool` CLI. Config goes via STDIN (v1.7.0).
final class Ch57xTool {
    enum ToolError: LocalizedError {
        case binaryNotFound
        case launchFailed(String)
        case failed(exit: Int32, output: String)

        var errorDescription: String? {
            switch self {
            case .binaryNotFound:
                return "ch57x-keyboard-tool binary not found (expected in app bundle Resources or ~/.local/bin)."
            case .launchFailed(let msg): return "Could not launch tool: \(msg)"
            case .failed(let code, let output):
                return "Tool exited with \(code):\n\(output)"
            }
        }
    }

    /// Candidate lookup order: bundled resource, dev checkout, PATH-installed.
    static func binaryURL() -> URL? {
        var candidates: [URL] = []
        if let res = Bundle.main.resourceURL?.appendingPathComponent("ch57x-keyboard-tool") {
            candidates.append(res)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        candidates.append(home.appendingPathComponent(".local/bin/ch57x-keyboard-tool"))
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// Runs a subcommand with YAML on stdin. Returns (stdout+stderr, exit code).
    private func run(subcommand: String, stdin yaml: String) throws -> (String, Int32) {
        guard let url = Self.binaryURL() else { throw ToolError.binaryNotFound }
        let proc = Process()
        proc.executableURL = url
        proc.arguments = [subcommand]
        let inPipe = Pipe()
        let outPipe = Pipe()
        proc.standardInput = inPipe
        proc.standardOutput = outPipe
        proc.standardError = outPipe
        do {
            try proc.run()
        } catch {
            throw ToolError.launchFailed(error.localizedDescription)
        }
        // Write stdin fully (small payload; safe to do before reading).
        inPipe.fileHandleForWriting.write(Data(yaml.utf8))
        inPipe.fileHandleForWriting.closeFile()
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (output, proc.terminationStatus)
    }

    /// Throws with the tool's message when validation fails.
    func validate(_ yaml: String) throws {
        let (output, code) = try run(subcommand: "validate", stdin: yaml)
        if code != 0 { throw ToolError.failed(exit: code, output: output.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    /// Uploads mapping to the connected pad. DESTRUCTIVE on-device.
    func upload(_ yaml: String) throws {
        let (output, code) = try run(subcommand: "upload", stdin: yaml)
        if code != 0 { throw ToolError.failed(exit: code, output: output.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    /// Raw output of show-keys (for the M2 action picker).
    func showKeys() throws -> String {
        guard let url = Self.binaryURL() else { throw ToolError.binaryNotFound }
        let proc = Process()
        proc.executableURL = url
        proc.arguments = ["show-keys"]
        let outPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = Pipe()
        try proc.run()
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
