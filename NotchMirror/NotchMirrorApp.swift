import SwiftUI
import AppKit
import AVFoundation
import ServiceManagement   // SMAppService — login item API (macOS 13+)

@main
struct NotchMirrorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var notchWindowController: NotchWindowController?

    // Persisted preference: did the user enable launch-at-login?
    private let loginItemKey = "launchAtLogin"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Register login item status on first launch
        setupLoginItem()

        // Pre-request camera permission so the system dialog
        // appears with proper app context, not inside a panel click.
        AVCaptureDevice.requestAccess(for: .video) { _ in
            DispatchQueue.main.async {
                self.notchWindowController = NotchWindowController()
                self.notchWindowController?.showWindow(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // -----------------------------------------------------------------------
    // MARK: – Login item (SMAppService, macOS 13+)
    // -----------------------------------------------------------------------

    /// Call once at launch. Registers the app as a login item the first time
    /// it runs. If the user has previously toggled it off, we respect that.
    private func setupLoginItem() {
        let defaults = UserDefaults.standard

        // "firstLaunch" flag — only auto-register once
        if !defaults.bool(forKey: "hasAskedLoginItem") {
            defaults.set(true, forKey: "hasAskedLoginItem")
            // Default to enabled on first launch
            setLaunchAtLogin(true)
            defaults.set(true, forKey: loginItemKey)
        }
    }

    /// Enables or disables the login item using SMAppService.
    /// Safe to call from anywhere (e.g. a Settings toggle).
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            UserDefaults.standard.set(enabled, forKey: loginItemKey)
        } catch {
            // SMAppService can fail if the app isn't signed or if the user
            // has blocked it in System Settings → General → Login Items.
            // Fail silently — the app still works, just won't auto-launch.
            print("NotchMirror: login item \(enabled ? "register" : "unregister") failed: \(error)")
        }
    }

    /// Current login item state (for a Settings toggle if you add one later).
    var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
