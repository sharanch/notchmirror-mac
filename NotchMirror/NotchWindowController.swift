import AppKit
import SwiftUI

protocol NotchWindowResizable: AnyObject {
    func setExpanded(_ expanded: Bool)
}

class NotchWindowController: NSWindowController, NotchWindowResizable {

    private let clipboardBtnWidth: CGFloat = 36
    private let cardWidth:  CGFloat = 280
    private let cardHeight: CGFloat = 330

    convenience init() {
        let window = NotchWindow()
        self.init(window: window)
        positionWindow(expanded: false)
        setupNotifications()
    }

    func setExpanded(_ expanded: Bool) {
        positionWindow(expanded: expanded)
    }

    // Returns notch rect in screen coordinates (points, not pixels)
    // Works correctly at all scaling factors by deriving position from
    // auxiliaryTopLeftArea / auxiliaryTopRightArea which are always in points.
    private func notchRect(for screen: NSScreen) -> CGRect {
        let h = screen.safeAreaInsets.top
        guard h > 0 else { return .zero }

        let sf = screen.frame

        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            // Notch X = screen.origin.x + left area width
            // Notch width = screen width - left width - right width
            let notchX = sf.minX + left.width
            let notchW = sf.width - left.width - right.width
            return CGRect(x: notchX, y: sf.maxY - h, width: max(notchW, 60), height: h)
        }

        // Fallback: assume centered notch
        let fallbackW: CGFloat = 162 // 81pt * 2x — common MBA value
        return CGRect(
            x: sf.midX - fallbackW / 2,
            y: sf.maxY - h,
            width: fallbackW,
            height: h
        )
    }

    private func positionWindow(expanded: Bool) {
        guard let screen = NSScreen.main,
              let window = self.window else { return }

        // Only show on screens with a notch
        guard screen.safeAreaInsets.top > 0 else {
            window.orderOut(nil)
            return
        }

        let notch = notchRect(for: screen)
        guard notch.width > 0 else { return }

        let windowX: CGFloat
        let windowY: CGFloat
        let windowWidth: CGFloat
        let windowHeight: CGFloat

        if expanded {
            // Window anchors at notch left edge, extends right by cardWidth + clipboard btn
            // Card is centered under the notch pill
            let expandedW = max(cardWidth, notch.width) + clipboardBtnWidth
            windowWidth  = expandedW
            windowHeight = notch.height + cardHeight
            // Keep pill aligned to notch — anchor window X to notch origin
            windowX = notch.minX
        } else {
            windowWidth  = notch.width + clipboardBtnWidth
            windowHeight = notch.height
            windowX      = notch.minX
        }
        windowY = notch.minY - (windowHeight - notch.height)  // top of window = top of screen

        // Clamp to screen bounds so it never overflows on non-standard scaling
        let sf = screen.frame
        let clampedX = min(max(windowX, sf.minX), sf.maxX - windowWidth)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.38
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(
                CGRect(x: clampedX, y: windowY, width: windowWidth, height: windowHeight),
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

    override func mouseDown(with event: NSEvent) {
        let loc = event.locationInWindow
        if loc.y >= frame.height - pillHitHeight {
            onPillClick?()
        } else {
            super.mouseDown(with: event)
        }
    }
}