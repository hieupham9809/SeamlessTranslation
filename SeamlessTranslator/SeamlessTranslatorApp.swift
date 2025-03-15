import SwiftUI

@main
struct SeamlessTranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            // No main window, only overlay window
        }
    }
}
