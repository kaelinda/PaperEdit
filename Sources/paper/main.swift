import Foundation

private let executableName = "paper"

private func printUsage() {
    print("""
    Usage: \(executableName) <file-or-directory> [...]

    Opens files as tabs and directories as the PaperEdit workspace.
    """)
}

private let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.isEmpty || arguments.contains("--help") || arguments.contains("-h") {
    printUsage()
    exit(arguments.isEmpty ? 1 : 0)
}

let paths = arguments.filter { !$0.hasPrefix("-") }

if paths.isEmpty {
    printUsage()
    exit(1)
}

let resolvedPaths = paths.map { argument -> String in
    let expandedPath = NSString(string: argument).expandingTildeInPath
    if expandedPath.hasPrefix("/") {
        return expandedPath
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(expandedPath)
        .path
}

for path in resolvedPaths where !FileManager.default.fileExists(atPath: path) {
    fputs("\(executableName): no such file or directory: \(path)\n", stderr)
    exit(66)
}

let executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
let adjacentAppPath = executableURL
    .deletingLastPathComponent()
    .appendingPathComponent("PaperEdit.app")
    .path
let appSpecifier = ProcessInfo.processInfo.environment["PAPEREDIT_APP_PATH"]
    ?? (FileManager.default.fileExists(atPath: adjacentAppPath) ? adjacentAppPath : "PaperEdit")

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
process.arguments = ["-a", appSpecifier] + resolvedPaths

do {
    try process.run()
    process.waitUntilExit()
    exit(process.terminationStatus)
} catch {
    fputs("\(executableName): failed to open PaperEdit: \(error.localizedDescription)\n", stderr)
    exit(69)
}
