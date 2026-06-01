import SwiftUI
import AppKit

// ---------------------------------------------------------------------------
// MARK: – Layout
// ---------------------------------------------------------------------------

private enum Layout {
    // Fallback notch constants (MBAir M2/M3, 2× Retina)
    // Real values are read at runtime from NSScreen.auxiliaryTopLeftArea etc.
    static let notchWidthFallback:  CGFloat = 81
    static let notchHeightFallback: CGFloat = 18.5

    // Camera card (below notch) — 16:9 landscape mirror, wide enough to feel immersive
    static let cardWidth:           CGFloat = 380   // wide enough for a proper mirror view
    static let cardHeight:          CGFloat = 214   // 16:9 ratio (380 × 9/16 ≈ 214)

    // Corner radii
    static let pillRadius:          CGFloat = 9    // tight, matches HW notch
    static let squircleRadius:      CGFloat = 32   // rounder squircle for camera card

    // Clipboard button (sits to the RIGHT of the notch, fully outside it)
    static let clipboardBtnSize:    CGFloat = 26
    static let clipboardPad:        CGFloat = 8    // gap between notch edge and btn center

    static let animDuration:        Double  = 0.38
}

// ---------------------------------------------------------------------------
// MARK: – Runtime notch size
// ---------------------------------------------------------------------------

private func liveNotchSize() -> CGSize {
    guard let screen = NSScreen.main else {
        return CGSize(width: Layout.notchWidthFallback, height: Layout.notchHeightFallback)
    }
    let h = screen.safeAreaInsets.top
    guard h > 0 else {
        return CGSize(width: Layout.notchWidthFallback, height: Layout.notchHeightFallback)
    }
    if let l = screen.auxiliaryTopLeftArea, let r = screen.auxiliaryTopRightArea {
        let w = screen.frame.width - l.width - r.width
        return CGSize(width: max(w, 60), height: h)
    }
    return CGSize(width: Layout.notchWidthFallback, height: h)
}

// ---------------------------------------------------------------------------
// MARK: – Global click monitor
// ---------------------------------------------------------------------------

class GlobalClickMonitor {
    private var monitor: Any?
    var onOutsideClick: (() -> Void)?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in self?.onOutsideClick?()
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }
}

// ---------------------------------------------------------------------------
// MARK: – Root view
// ---------------------------------------------------------------------------

struct NotchView: View {
    @StateObject private var camera    = CameraManager()
    @StateObject private var clipboard = ClipboardManager()

    @State private var isExpanded    = false
    @State private var showClipboard = false
    @State private var notchSize     = liveNotchSize()

    private let clickMonitor = GlobalClickMonitor()

    // The window is exactly [notchWidth + clipboardBtnArea] wide.
    // Pill occupies the LEFT portion (notchWidth), clipboard btn the RIGHT.
    // No offsets or Spacers needed — simple HStack, no tricks.

    var body: some View {
        // When expanded the window grows left by overhang = (cardWidth - notchWidth)/2
        // so the card can sit centred. The pill must be pushed right by that same amount.
        let overhang: CGFloat = isExpanded
            ? max((Layout.cardWidth - notchSize.width) / 2, 0)
            : 0

        VStack(alignment: .leading, spacing: 0) {

            // ── Row 1: notch row ──────────────────────────────────────────
            // Pill is offset right by overhang so it stays over the hardware notch.
            HStack(alignment: .center, spacing: 0) {
                Spacer().frame(width: overhang)   // left padding = window overhang
                notchPill
                Spacer().frame(width: Layout.clipboardPad)
                clipboardButton
                    .frame(width: Layout.clipboardBtnSize, height: Layout.clipboardBtnSize)
                Spacer()
            }
            .frame(height: notchSize.height, alignment: .top)

            // ── Row 2: camera card ────────────────────────────────────────
            // The window is already symmetrically wider, so the card just
            // needs to be centred in the full window width (excluding clipboard btn).
            if isExpanded {
                HStack(spacing: 0) {
                    Spacer()
                    cameraCard
                    // Push left of clipboard btn area so card stays visually centred
                    // under the notch, not under the notch+clipboard region.
                    Spacer().frame(width: Layout.clipboardBtnSize + Layout.clipboardPad)
                }
                .padding(.top, 6)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.94, anchor: .top).combined(with: .opacity),
                    removal:   .scale(scale: 0.94, anchor: .top).combined(with: .opacity)
                ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { notchSize = liveNotchSize() }
    }

    // -----------------------------------------------------------------------
    // MARK: – Notch pill
    // -----------------------------------------------------------------------

    private var notchPill: some View {
        RoundedRectangle(cornerRadius: Layout.pillRadius, style: .continuous)
            .fill(Color.black)
            .frame(width: notchSize.width, height: notchSize.height)
            // No onTapGesture — NotchWindow.mouseDown handles first click
            // at the NSWindow level, bypassing the nonactivatingPanel focus issue.
            .onHover { h in h ? NSCursor.pointingHand.push() : NSCursor.pop() }
            .onAppear {
                (NSApp.windows.first { $0 is NotchWindow } as? NotchWindow)?
                    .onPillClick = { toggleExpand() }
            }
    }

    // -----------------------------------------------------------------------
    // MARK: – Camera card (squircle, below notch)
    // -----------------------------------------------------------------------

    private var cameraCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Layout.squircleRadius, style: .continuous)
                .fill(Color.black)
                .shadow(color: .black.opacity(0.55), radius: 20, y: 8)

            cameraContent
                .clipShape(RoundedRectangle(cornerRadius: Layout.squircleRadius, style: .continuous))

            // Bottom vignette
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.35)],
                    startPoint: .center, endPoint: .bottom
                )
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: Layout.squircleRadius, style: .continuous))
            }
        }
        .frame(width: Layout.cardWidth, height: Layout.cardHeight)
    }

    // -----------------------------------------------------------------------
    // MARK: – Camera content
    // -----------------------------------------------------------------------

    @ViewBuilder
    private var cameraContent: some View {
        if camera.permissionDenied {
            VStack(spacing: 10) {
                Image(systemName: "camera.slash.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white.opacity(0.4))
                Text("Camera access required")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                Button("Open Privacy Settings") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!
                    )
                }
                .buttonStyle(PillButtonStyle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        } else if camera.isRunning {
            CameraPreviewView(session: camera.session)
        } else {
            VStack(spacing: 8) {
                ProgressView().progressViewStyle(.circular).scaleEffect(0.7).tint(.white)
                Text("Starting camera…")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
    }

    // -----------------------------------------------------------------------
    // MARK: – Clipboard button
    // -----------------------------------------------------------------------

    private var clipboardButton: some View {
        Button { showClipboard.toggle() } label: {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: Layout.clipboardBtnSize, height: Layout.clipboardBtnSize)
                Image(systemName: clipboard.hasContent ? "clipboard.fill" : "clipboard")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(clipboard.hasContent ? .white : .white.opacity(0.4))
                if clipboard.hasContent {
                    Circle()
                        .fill(Color(red: 0.2, green: 0.85, blue: 0.4))
                        .frame(width: 5, height: 5)
                        .offset(x: 7, y: -7)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { h in h ? NSCursor.pointingHand.push() : NSCursor.pop() }
        .popover(isPresented: $showClipboard, arrowEdge: .bottom) {
            ClipboardPopover(clipboard: clipboard)
        }
    }

    // -----------------------------------------------------------------------
    // MARK: – Expand / collapse
    // -----------------------------------------------------------------------

    private func toggleExpand() {
        isExpanded.toggle()
        if let ctrl = NSApp.windows
            .compactMap({ $0.windowController as? NotchWindowResizable }).first {
            ctrl.setExpanded(isExpanded)
        }
        if isExpanded {
            camera.startSession()
            clickMonitor.onOutsideClick = { collapse() }
            clickMonitor.start()
        } else {
            collapse()
        }
    }

    private func collapse() {
        guard isExpanded else { return }
        clickMonitor.stop()
        withAnimation(.spring(response: Layout.animDuration, dampingFraction: 0.82)) {
            isExpanded = false
        }
        if let ctrl = NSApp.windows
            .compactMap({ $0.windowController as? NotchWindowResizable }).first {
            ctrl.setExpanded(false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Layout.animDuration) {
            camera.stopSession()
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: – Clipboard popover
// ---------------------------------------------------------------------------

struct ClipboardPopover: View {
    @ObservedObject var clipboard: ClipboardManager
    @State private var searchText = ""
    @State private var hoveredId: UUID? = nil

    private var filtered: [ClipboardItem] {
        guard !searchText.isEmpty else { return clipboard.items }
        return clipboard.items.filter {
            switch $0.content {
            case .text(let t):  return t.localizedCaseInsensitiveContains(searchText)
            case .image:        return "image".contains(searchText.lowercased())
            }
        }
    }

    private func shortcut(for index: Int) -> String { index < 9 ? "⌘\(index + 1)" : "" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("Clipboard")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 60, alignment: .leading)
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                    TextField("type to search…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .padding(.horizontal, 12).padding(.vertical, 10)

            Divider().background(Color.white.opacity(0.08))

            if filtered.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "clipboard").font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.15))
                    Text(searchText.isEmpty ? "Nothing copied yet" : "No results")
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, item in
                            ClipboardRow(
                                item: item, shortcut: shortcut(for: idx),
                                isHovered: hoveredId == item.id,
                                onTap: { clipboard.copy(item) }
                            )
                            .onHover { h in hoveredId = h ? item.id : nil }
                            if idx < filtered.count - 1 {
                                Divider().background(Color.white.opacity(0.05)).padding(.leading, 10)
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 340)
        .background(Color(white: 0.10))
        .preferredColorScheme(.dark)
    }
}

struct ClipboardRow: View {
    let item: ClipboardItem
    let shortcut: String
    let isHovered: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                switch item.content {
                case .text(let t):
                    Image(systemName: t.hasPrefix("http") ? "link" : "doc.on.clipboard")
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.3)).frame(width: 16)
                case .image(let img):
                    Image(nsImage: img).resizable().scaledToFill()
                        .frame(width: 28, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Text(item.preview).font(.system(size: 13)).foregroundColor(.white.opacity(0.85))
                    .lineLimit(1).truncationMode(.tail).frame(maxWidth: .infinity, alignment: .leading)
                if !shortcut.isEmpty {
                    Text(shortcut).font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.25)).frame(width: 32, alignment: .trailing)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(isHovered ? Color.white.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.black)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Color.white.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
