import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    var fileOpenHandler: (([URL]) -> Void)? {
        didSet {
            flushPendingOpenURLs()
        }
    }
    private var pendingOpenURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let urls = CommandLineOpenRequest.urls(
            from: Array(CommandLine.arguments.dropFirst()),
            currentDirectoryURL: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        )
        open(urls)
    }

    func application(_ application: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        open(urls)
        application.reply(toOpenOrPrint: .success)
    }

    private func open(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        guard let fileOpenHandler else {
            pendingOpenURLs.append(contentsOf: urls)
            return
        }
        fileOpenHandler(urls)
    }

    private func flushPendingOpenURLs() {
        guard let fileOpenHandler, !pendingOpenURLs.isEmpty else { return }
        let urls = pendingOpenURLs
        pendingOpenURLs = []
        fileOpenHandler(urls)
    }
}
