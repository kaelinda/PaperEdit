import Foundation

enum CommandLineOpenRequest {
    static func urls(from arguments: [String], currentDirectoryURL: URL) -> [URL] {
        arguments
            .filter { !$0.isEmpty && !$0.hasPrefix("-") }
            .map { argument in
                let expandedPath = NSString(string: argument).expandingTildeInPath
                if expandedPath.hasPrefix("/") {
                    return URL(fileURLWithPath: expandedPath)
                }
                return currentDirectoryURL.appendingPathComponent(expandedPath)
            }
    }
}
