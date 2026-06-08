import AppKit
import Combine

// ---------------------------------------------------------------------------
// MARK: – ClipboardContent
// ---------------------------------------------------------------------------

enum ClipboardContent {
    case text(String)
    case image(NSImage)
}

// ---------------------------------------------------------------------------
// MARK: – ClipboardItem — supports text AND images (screenshots)
// ---------------------------------------------------------------------------

struct ClipboardItem: Identifiable, Equatable, Codable {
    let id: UUID
    let content: ClipboardContent
    var isPinned: Bool

    init(content: ClipboardContent, isPinned: Bool = false) {
        self.id = UUID()
        self.content = content
        self.isPinned = isPinned
    }

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

    // ── Codable ──────────────────────────────────────────────────────────

    enum CodingKeys: String, CodingKey { case id, type, text, imageData, isPinned }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(isPinned, forKey: .isPinned)
        switch content {
        case .text(let t):
            try c.encode("text", forKey: .type)
            try c.encode(t, forKey: .text)
        case .image(let img):
            try c.encode("image", forKey: .type)
            if let tiff = img.tiffRepresentation,
               let bmp  = NSBitmapImageRep(data: tiff),
               let png  = bmp.representation(using: .png, properties: [:]) {
                try c.encode(png, forKey: .imageData)
            }
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(UUID.self,   forKey: .id)
        isPinned = (try? c.decode(Bool.self, forKey: .isPinned)) ?? false
        let type = try c.decode(String.self, forKey: .type)
        if type == "image",
           let data  = try? c.decode(Data.self, forKey: .imageData),
           let image = NSImage(data: data) {
            content = .image(image)
        } else {
            let t = (try? c.decode(String.self, forKey: .text)) ?? ""
            content = .text(t)
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
    private let maxItems = 50
    private let storageKey = "com.notchmirror.clipboard.items"
    private let storageURL: URL = {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NotchThing", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("clipboard.json")
    }()

    override init() {
        super.init()
        loadFromDisk()
        lastChangeCount = NSPasteboard.general.changeCount
        poll()
        startMonitoring()
    }

    var currentContent: String { items.first?.text ?? "" }

    // ── Sorted view: pinned first, then recents ──────────────────────────
    var pinnedItems:  [ClipboardItem] { items.filter(\.isPinned) }
    var recentItems:  [ClipboardItem] { items.filter { !$0.isPinned } }

    // -----------------------------------------------------------------------
    // MARK: – Persistence
    // -----------------------------------------------------------------------

    func saveToDisk() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: storageURL),
              let saved = try? JSONDecoder().decode([ClipboardItem].self, from: data)
        else { return }
        items = saved
        hasContent = !items.isEmpty
    }

    // -----------------------------------------------------------------------
    // MARK: – Monitoring
    // -----------------------------------------------------------------------

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            let count = NSPasteboard.general.changeCount
            if count != self?.lastChangeCount {
                self?.lastChangeCount = count
                self?.poll()
            }
        }
    }

    private func poll() {
        let pb = NSPasteboard.general

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

        if let text = pb.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let newItem = ClipboardItem(content: .text(text))
            DispatchQueue.main.async { self.push(newItem) }
        }
    }

    private func push(_ newItem: ClipboardItem) {
        if items.first == newItem { return }
        items.removeAll { $0 == newItem }
        // Insert after any pinned items so recents don't disturb pinned order
        let insertIdx = items.firstIndex(where: { !$0.isPinned }) ?? items.endIndex
        items.insert(newItem, at: insertIdx)
        if items.count > maxItems {
            // Trim only unpinned items from the tail
            while items.count > maxItems, let last = items.indices.last, !items[last].isPinned {
                items.removeLast()
            }
        }
        hasContent = !items.isEmpty
        saveToDisk()
    }

    // -----------------------------------------------------------------------
    // MARK: – Actions
    // -----------------------------------------------------------------------

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
        DispatchQueue.main.async {
            // Move to top of recents (after pinned)
            if let idx = self.items.firstIndex(where: { $0.id == item.id }) {
                var moved = self.items.remove(at: idx)
                moved.isPinned = item.isPinned // preserve pin state
                let insertIdx = self.items.firstIndex(where: { !$0.isPinned }) ?? self.items.endIndex
                self.items.insert(moved, at: moved.isPinned ? 0 : insertIdx)
            }
            self.saveToDisk()
        }
    }

    func togglePin(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isPinned.toggle()
        let wasPinned = !items[idx].isPinned
        // Re-sort: pinned always above unpinned
        let pinned  = items.filter(\.isPinned)
        let recents = items.filter { !$0.isPinned }
        items = pinned + recents
        hasContent = !items.isEmpty
        saveToDisk()
        _ = wasPinned // suppress warning
    }

    func clearAll() {
        // Keep pinned items
        items = items.filter(\.isPinned)
        hasContent = !items.isEmpty
        saveToDisk()
    }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        hasContent = !items.isEmpty
        saveToDisk()
    }

    deinit { timer?.invalidate() }
}
