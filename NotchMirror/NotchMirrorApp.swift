import SwiftUI
import AppKit
import AVFoundation
import ServiceManagement

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

    private let loginItemKey = "launchAtLogin"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupLoginItem()
        blockCmdQ()

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
    // MARK: – Block Cmd+Q
    // -----------------------------------------------------------------------

    private func blockCmdQ() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers == "q" {
                return nil // swallow — don't quit
            }
            return event
        }
    }

    // -----------------------------------------------------------------------
    // MARK: – Login item
    // -----------------------------------------------------------------------

    private func setupLoginItem() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "hasAskedLoginItem") {
            defaults.set(true, forKey: "hasAskedLoginItem")
            setLaunchAtLogin(true)
            defaults.set(true, forKey: loginItemKey)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            UserDefaults.standard.set(enabled, forKey: loginItemKey)
        } catch {
            print("NotchMirror: login item \(enabled ? "register" : "unregister") failed: \(error)")
        }
    }

    var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}