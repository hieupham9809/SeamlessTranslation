import Cocoa
import SwiftUI
import HotKey

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var overlayWindow: NSWindow!
    private var quickPasteHotKey: HotKey?
    private var quickPasteEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "quickPasteEnabled")
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the overlay window
        overlayWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 400, width: 400, height: 300),
            styleMask: [.titled, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        overlayWindow.isOpaque = false
        overlayWindow.backgroundColor = .clear
        overlayWindow.styleMask.insert(.miniaturizable)
        overlayWindow.level = .floating // Change to floating level to appear on all spaces
        overlayWindow.collectionBehavior = [.moveToActiveSpace] // Allow window to move between spaces
        overlayWindow.contentView = NSHostingView(rootView: OverlayView())
        overlayWindow.makeKeyAndOrderFront(nil)
        overlayWindow.delegate = self
        
        // Ensure quickPasteEnabled has a default value of true
        if UserDefaults.standard.object(forKey: "quickPasteEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "quickPasteEnabled")
        }
        
        // Set up quick paste hotkey (Command+Shift+P)
        setupQuickPasteHotkey()
        
        // Monitor changes to the quickPasteEnabled setting
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func userDefaultsDidChange(_ notification: Notification) {
        // Update hotkey activation based on the quickPasteEnabled setting
        if quickPasteEnabled {
            quickPasteHotKey?.isPaused = false
        } else {
            quickPasteHotKey?.isPaused = true
        }
    }
    
    private func setupQuickPasteHotkey() {
        quickPasteHotKey = HotKey(key: .p, modifiers: [.command, .shift])
        
        // Set initial pause state based on the setting
        quickPasteHotKey?.isPaused = !quickPasteEnabled
        
        quickPasteHotKey?.keyDownHandler = { [weak self] in
            self?.handleQuickPaste()
        }
    }
    
    private func handleQuickPaste() {
        // Check if the feature is enabled (for extra safety)
        guard quickPasteEnabled else { return }
        
        // Simply get content from pasteboard
        let pasteboard = NSPasteboard.general
        guard let clipboardString = pasteboard.string(forType: .string) else { return }
        
        // Move window to active space instead of changing spaces
        self.overlayWindow.collectionBehavior = [.moveToActiveSpace]
        
        // Make our window visible on the current space without activating the app
        self.overlayWindow.orderFront(nil)
        
        // Post notification to paste text into TranslateView
        NotificationCenter.default.post(
            name: Notification.Name("QuickPasteEvent"),
            object: nil,
            userInfo: ["text": clipboardString]
        )
        
        // Activate our app but maintain the current space
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    // NSWindowDelegate method to handle window closing
    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.terminate(self) // Terminate the application
    }
}
