import AppKit
import SwiftUI

protocol NotchWindowResizable: AnyObject {
    func setExpanded(_ expanded: Bool)
}

class NotchWindowController: NSWindowController, NotchWindowResizable {

    private let clipboardBtnWidth: CGFloat = 36
    private let cardWidth:  CGFloat = 280
    private let cardHeight: CGFloat = 320

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

        let notch = notchSize(for: screen)
        guard notch.width > 0 else { return }

        let sf = screen.frame

        let windowWidth: CGFloat
        let windowHeight: CGFloat
        let windowX: CGFloat
        let windowY: CGFloat

        if expanded {
            let totalWidth = max(cardWidth, notch.width) + clipboardBtnWidth
            windowWidth  = totalWidth
            windowHeight = notch.height + cardHeight
            windowX      = sf.midX - max(cardWidth, notch.width) / 2
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
    }
}

// ---------------------------------------------------------------------------
// MARK: – NotchWindow
// ---------------------------------------------------------------------------

class NotchWindow: NSPanel {

    // Set by NotchView after init so the window can fire toggle directly
    var onPillClick: (() -> Void)?

    // The notch pill height — clicks in this top band trigger onPillClick.
    // Slightly generous (24 pt) vs the physical ~18.5 pt so it's easy to hit.
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
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
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

    // -------------------------------------------------------------------------
    // Intercept mouseDown at the NSWindow level — fires on the FIRST click
    // regardless of whether the panel is currently key/focused.
    // Clicks in the pill band (top pillHitHeight pts) go to onPillClick.
    // Everything else falls through to SwiftUI normally.
    // -------------------------------------------------------------------------
    override func mouseDown(with event: NSEvent) {
        let loc = event.locationInWindow
        // locationInWindow is in window-flipped coords: y=0 at bottom.
        // The pill is at the TOP of the window, so y >= height - pillHitHeight.
        if loc.y >= frame.height - pillHitHeight {
            onPillClick?()
        } else {
            super.mouseDown(with: event)
        }
    }
}
