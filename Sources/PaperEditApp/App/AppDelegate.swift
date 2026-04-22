import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    var fileOpenHandler: (([URL]) -> Void)?

    func application(_ application: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        fileOpenHandler?(urls)
        application.reply(toOpenOrPrint: .success)
    }
}
