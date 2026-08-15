import AppKit

@MainActor
final class IconRepository {
    static let shared = IconRepository()

    private let cache = NSCache<NSString, NSImage>()

    func icon(for source: IconSource, size: CGFloat) -> NSImage? {
        let key = key(for: source, size: size)
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let base = baseImage(for: source) else { return nil }
        let sized = resize(base, to: size)
        cache.setObject(sized, forKey: key)
        return sized
    }

    private func key(for source: IconSource, size: CGFloat) -> NSString {
        let suffix: String
        switch source {
        case .application(let url): suffix = url.path
        case .file(let url): suffix = url.path
        case .symbol(let name): suffix = "symbol:\(name)"
        }
        return "\(suffix)#\(Int(size))" as NSString
    }

    private func baseImage(for source: IconSource) -> NSImage? {
        switch source {
        case .application(let url):
            return NSWorkspace.shared.icon(forFile: url.path)
        case .file(let url):
            return NSWorkspace.shared.icon(forFile: url.path)
        case .symbol(let name):
            return NSImage(systemSymbolName: name, accessibilityDescription: nil)
        }
    }

    private func resize(_ image: NSImage, to size: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
            return true
        }
    }
}