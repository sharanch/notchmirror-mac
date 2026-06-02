import AppKit
import SwiftUI

protocol NotchWindowResizable: AnyObject {
    func setExpanded(_ expanded: Bool)
}

class NotchWindowController: NSWindowController, NotchWindowResizable {

    private let clipboardBtnWidth: CGFloat = 36
    private let cardWidth:  CGFloat = 380
    private let cardHeight: CGFloat = 214

    convenience init() {
        let window = NotchWindow()
        self.init(window: window)
        positionWindow(expanded: false)
        setupNotifications()
    }

    func setExpanded(_ expanded: Bool) {
        positionWindow(expanded: expanded)
    }

    private func notchSize(for screen: NSScreen) -> CGSize {
        let h = screen.safeAreaInsets.top
        guard h > 0 else { return .zero }
        if let l = screen.auxiliaryTopLeftArea, let r = screen.auxiliaryTopRightArea {
            let w = screen.frame.width - l.width - r.width
            return CGSize(width: max(w, 60), height: h)
        }
        return CGSize(width: 81, height: h)
    }

    private func positionWindow(expanded: Bool) {
        guard let screen = NSScreen.main,
              let window = self.window else { return }

        // Only show on screens with a notch — hide on external monitors
        guard screen.safeAreaInsets.top > 0 else {
            window.orderOut(nil)
            return
        }

        let notch = notchSize(for: screen)
        guard notch.width > 0 else { return }

        let sf = screen.frame

        let windowWidth: CGFloat
        let windowHeight: CGFloat
        let windowX: CGFloat
        let windowY: CGFloat

        if expanded {
            // The card is wider than the notch pill, so we must grow the window
            // leftward AND rightward equally so the card sits centred under the
            // hardware notch. Strategy:
            //   • notch pill stays anchored at the notch centre
            //   • extra card overhang = (cardWidth - notchWidth) / 2 per side
            //   • clipboard btn still hangs off the right
            let overhang = max((cardWidth - notch.width) / 2, 0)
            windowWidth  = overhang + notch.width + overhang + clipboardBtnWidth
            windowHeight = notch.height + cardHeight
            // Shift window left by overhang so the pill stays over the notch
            windowX      = sf.midX - notch.width / 2 - overhang
        } else {
            windowWidth  = notch.width + clipboardBtnWidth
            windowHeight = notch.height
            windowX      = sf.midX - notch.width / 2
        }
        windowY = sf.maxY - windowHeight

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.38
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(
                CGRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight),
                display: true
            )
        }
        window.orderFrontRegardless()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenConfigurationChanged() {
        positionWindow(expanded: false)
        // Re-show if main screen has notch (e.g. unplugged external monitor)
        if let screen = NSScreen.main, screen.safeAreaInsets.top > 0 {
            window?.orderFrontRegardless()
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: – NotchWindow
// ---------------------------------------------------------------------------

class NotchWindow: NSPanel {

    var onPillClick: (() -> Void)?

    private let pillHitHeight: CGFloat = 24

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.stationary, .ignoresCycle]
        self.isMovable = false
        self.acceptsMouseMovedEvents = true

        let notchView = NotchView()
        let hostingView = NSHostingView(rootView: notchView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        hostingView.layer?.masksToBounds = false
        self.contentView = hostingView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        // Become key immediately on first click so SwiftUI controls (buttons,
        // popovers, gestures) fire without needing a second "activating" click.
        // nonactivatingPanel normally skips key promotion, which is why the
        // camera area required two clicks while the clipboard button worked fine
        // (popover presentation bypasses the issue; direct tap-gestures do not).
        if !isKeyWindow {
            makeKey()
        }

        let loc = event.locationInWindow
        if loc.y >= frame.height - pillHitHeight {
            onPillClick?()
        } else {
            super.mouseDown(with: event)
        }
    }
}