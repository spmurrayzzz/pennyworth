import AppKit
@preconcurrency import QuickLookUI

@MainActor
final class QuickLookController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookController()

    private var currentURL: URL?

    private override init() {
        super.init()
    }

    var isPreviewVisible: Bool {
        QLPreviewPanel.shared()?.isVisible ?? false
    }

    /// Toggle the shared preview for a URL.
    @discardableResult
    func togglePreview(for url: URL) -> Bool {
        guard let panel = QLPreviewPanel.shared() else { return false }
        if panel.isVisible {
            panel.close()
            return false
        }
        currentURL = url
        panel.dataSource = self
        panel.delegate = self
        panel.orderFront(nil)
        return true
    }

    func showPreview(for url: URL) {
        guard let panel = QLPreviewPanel.shared() else { return }
        currentURL = url
        panel.dataSource = self
        panel.delegate = self
        panel.orderFront(nil)
    }

    func closeIfOpen() {
        guard let panel = QLPreviewPanel.shared() else { return }
        if panel.isVisible {
            panel.close()
        }
        currentURL = nil
    }

    func previewURL() -> URL? {
        currentURL
    }

    // MARK: - QLPreviewPanelDataSource

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated { currentURL == nil ? 0 : 1 }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        MainActor.assumeIsolated {
            guard let url = currentURL else { return nil }
            return PreviewItem(url: url)
        }
    }

    // MARK: - QLPreviewPanelDelegate

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, didClose closeReason: Bool) {
        MainActor.assumeIsolated {
            currentURL = nil
        }
    }
}

private final class PreviewItem: NSObject, QLPreviewItem, @unchecked Sendable {
    let previewItemURL: URL?
    let previewItemTitle: String?

    init(url: URL) {
        previewItemURL = url
        previewItemTitle = url.lastPathComponent
    }
}