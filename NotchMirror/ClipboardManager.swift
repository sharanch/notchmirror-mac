import AppKit
import Combine

// ---------------------------------------------------------------------------
// MARK: – ClipboardItem — supports text AND images (screenshots)
// ---------------------------------------------------------------------------

enum ClipboardContent {
    case text(String)
    case image(NSImage)
}

struct ClipboardItem: Identifiable, Equatable {
    let id = UUID()
    let content: ClipboardContent

    var preview: String {
        switch content {
        case .text(let t):
            let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "(empty)" : trimmed
        case .image(let img):
            let w = Int(img.size.width)
            let h = Int(img.size.height)
            return "Image \(w) × \(h)"
        }
    }

    // For deduplication — compare text content or image object identity
    var text: String {
        if case .text(let t) = content { return t }
        return ""
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        switch (lhs.content, rhs.content) {
        case (.text(let a), .text(let b)):   return a == b
        case (.image(let a), .image(let b)): return a === b
        default:                             return false
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: – ClipboardManager
// ---------------------------------------------------------------------------

class ClipboardManager: NSObject, ObservableObject {
    @Published var items: [ClipboardItem] = []
    @Published var hasContent: Bool = false

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let maxItems = 20

    override init() {
        super.init()
        lastChangeCount = NSPasteboard.general.changeCount
        poll()
        startMonitoring()
    }

    var currentContent: String { items.first?.text ?? "" }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            let count = NSPasteboard.general.changeCount
            if count != self?.lastChangeCount {
                self?.lastChangeCount = count
                self?.poll()
            }
        }
    }

    /// Read the latest item from the pasteboard — text OR image.
    private func poll() {
        let pb = NSPasteboard.general

        // ── 1. Image types (screenshots, copied images) ────────────────────
        //   Check for image before text so a screenshot isn't mistaken for
        //   the filename string that macOS sometimes also puts on the board.
        let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("com.apple.screenshot.png")]

        for type in imageTypes {
            if pb.availableType(from: [type]) != nil,
               let data = pb.data(forType: type),
               let image = NSImage(data: data) {
                let newItem = ClipboardItem(content: .image(image))
                DispatchQueue.main.async { self.push(newItem) }
                return
            }
        }

        // ── 2. Plain text ──────────────────────────────────────────────────
        if let text = pb.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let newItem = ClipboardItem(content: .text(text))
            DispatchQueue.main.async { self.push(newItem) }
        }
    }

    private func push(_ newItem: ClipboardItem) {
        // Avoid exact duplicate at the top
        if items.first == newItem { return }
        // Remove any older copy of this item
        items.removeAll { $0 == newItem }
        items.insert(newItem, at: 0)
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        hasContent = !items.isEmpty
    }

    func copy(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.content {
        case .text(let t):
            pb.setString(t, forType: .string)
        case .image(let img):
            if let tiff = img.tiffRepresentation {
                pb.setData(tiff, forType: .tiff)
            }
        }
        // Move item to top in our list
        DispatchQueue.main.async {
            self.items.removeAll { $0.id == item.id }
            self.items.insert(item, at: 0)
        }
    }

    deinit { timer?.invalidate() }
}
