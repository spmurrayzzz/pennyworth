import AppKit
import QuickLookUI

@MainActor
final class PennyworthViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSSearchFieldDelegate {

    private enum RowModel {
        case result(SearchResult)
        case action(AvailableAction)
        case openWith(url: URL, title: String)

        var id: String {
            switch self {
            case .result(let result): "result:\(result.id)"
            case .action(let action): "action:\(action.id.rawValue)"
            case .openWith(url: let url, _): "openwith:\(url.path)"
            }
        }
    }

    private enum ViewMode {
        case results
        case actions(for: SearchResult)
        case openWith(for: SearchResult)

        var isActionMode: Bool {
            if case .results = self { return false }
            return true
        }
    }

    private let iconRepository = IconRepository.shared
    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let hintLabel = NSTextField(labelWithString: "")
    private let carouselBackground = NSVisualEffectView()

    var coordinator: SearchCoordinator?
    var executor: ActionExecutor?
    var selectionStore: SelectionStore?
    var onRequestDismiss: (() -> Void)?

    private var rows: [RowModel] = []
    private var mode: ViewMode = .results
    private var selectedIndex = 0
    private var localMonitor: Any?

    // MARK: - View construction

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 620, height: 340))

        carouselBackground.material = .popover
        carouselBackground.blendingMode = .behindWindow
        carouselBackground.state = .active
        carouselBackground.wantsLayer = true
        carouselBackground.layer?.cornerRadius = 12
        carouselBackground.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(carouselBackground)

        searchField.placeholderString = "Search applications, files, web, calculator, commands"
        searchField.font = .systemFont(ofSize: 18)
        searchField.controlSize = .large
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.delegate = self
        carouselBackground.addSubview(searchField)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 44
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.style = .plain
        tableView.backgroundColor = .clear
        tableView.allowsEmptySelection = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.selectionHighlightStyle = .regular

        scrollView.documentView = tableView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        carouselBackground.addSubview(scrollView)

        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        carouselBackground.addSubview(hintLabel)

        view = root

        NSLayoutConstraint.activate([
            carouselBackground.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
            carouselBackground.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 8),
            carouselBackground.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -8),
            carouselBackground.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -8),

            searchField.topAnchor.constraint(equalTo: carouselBackground.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: carouselBackground.leadingAnchor, constant: 14),
            searchField.trailingAnchor.constraint(equalTo: carouselBackground.trailingAnchor, constant: -14),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: carouselBackground.leadingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(equalTo: carouselBackground.trailingAnchor, constant: -4),

            hintLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 6),
            hintLabel.leadingAnchor.constraint(equalTo: carouselBackground.leadingAnchor, constant: 16),
            hintLabel.trailingAnchor.constraint(equalTo: carouselBackground.trailingAnchor, constant: -16),
            hintLabel.bottomAnchor.constraint(equalTo: carouselBackground.bottomAnchor, constant: -10),
        ])
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        installMonitor()
        view.window?.makeFirstResponder(searchField)
    }

    override func viewWillDisappear() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        super.viewWillDisappear()
    }

    private func installMonitor() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            // AppKit runs local handlers on the main thread, but the
            // handler type is not isolated. Extract only the Sendable
            // components of the event, then act on the main actor.
            let keyCode = event.keyCode
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let handled = MainActor.assumeIsolated {
                self.handleKeyEvent(keyCode: keyCode, modifiers: modifiers)
            }
            return handled ? nil : event
        }
    }

    // MARK: - Public entry points

    func beginNewQuery() {
        searchField.stringValue = ""
        rows = []
        mode = .results
        selectedIndex = 0
        hintLabel.stringValue = "Type to search."
        tableView.reloadData()
        view.window?.makeFirstResponder(searchField)
    }

    func applyResults(_ results: [SearchResult]) {
        guard mode.isActionMode == false else { return }
        let previousID = rows.indices.contains(selectedIndex) ? rows[selectedIndex].id : nil
        rows = results.map { .result($0) }
        if let previousID, let index = rows.firstIndex(where: { $0.id == previousID }) {
            selectedIndex = index
        } else if !rows.isEmpty {
            selectedIndex = 0
        } else {
            selectedIndex = -1
        }
        if results.isEmpty {
            switch coordinator?.lastParsed?.mode {
            case .fileOpen, .fileFind:
                hintLabel.stringValue = "No matching files. Spotlight may be disabled; check System Settings."
            default:
                hintLabel.stringValue = "No results."
            }
        } else {
            hintLabel.stringValue = ""
        }
        tableView.reloadData()
    }

    // MARK: - Search field

    func controlTextDidChange(_ obj: Notification) {
        let text = searchField.stringValue
        if text.isEmpty {
            mode = .results
        }
        coordinator?.update(query: text, limit: AppSettings.resultLimit)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector.description {
        case "moveUp:":
            moveSelection(offset: -1)
            return true
        case "moveDown:":
            moveSelection(offset: 1)
            return true
        case "insertNewline:":
            handleReturn()
            return true
        case "cancelOperation:":
            handleEscape()
            return true
        case "moveRight:":
            return handleRight(textView: textView)
        case "moveLeft:":
            return handleLeft()
        default:
            return false
        }
    }

    private func handleRight(textView: NSTextView) -> Bool {
        let selection = textView.selectedRange()
        let isAtEnd = selection.location == textView.string.count
        if isAtEnd && selection.length == 0, let result = selectedResult() {
            showActions(for: result)
            return true
        }
        return false
    }

    private func handleLeft() -> Bool {
        if mode.isActionMode {
            mode = .results
            coordinator?.update(query: searchField.stringValue, limit: AppSettings.resultLimit)
            return true
        }
        return false
    }

    private func handleEscape() {
        if !searchField.stringValue.isEmpty {
            searchField.stringValue = ""
            coordinator?.update(query: "", limit: AppSettings.resultLimit)
        } else {
            onRequestDismiss?()
        }
    }

    private func handleReturn() {
        guard !rows.isEmpty else { return }
        switch mode {
        case .results:
            runSelected()
        case .actions(let result):
            if case .action(let action) = rows[selectedIndex] {
                perform(action: action, for: result)
            }
        case .openWith(let result):
            if case .openWith(url: let url, title: let title) = rows[selectedIndex] {
                performOpenWith(url, titled: title, for: result)
            }
        }
    }

    private func runSelected() {
        guard let result = selectedResult() else { return }
        let action = ActionCatalog.primaryAction(for: result.kind)
        let available = ActionCatalog.actions(for: result.kind)
        if let match = available.first(where: { $0.id == action }) {
            perform(action: match, for: result)
        }
    }

    private func selectedResult() -> SearchResult? {
        guard rows.indices.contains(selectedIndex) else { return nil }
        if case .result(let result) = rows[selectedIndex] {
            return result
        }
        return nil
    }

    private func moveSelection(offset: Int) {
        guard !rows.isEmpty else { return }
        var newIndex = selectedIndex + offset
        newIndex = min(max(0, newIndex), rows.count - 1)
        selectedIndex = newIndex
        tableView.selectRowIndexes(IndexSet(integer: newIndex), byExtendingSelection: false)
        scrollToSelected()
    }

    private func scrollToSelected() {
        guard rows.indices.contains(selectedIndex) else { return }
        tableView.scrollRowToVisible(selectedIndex)
    }

    // MARK: - Table data source

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard rows.indices.contains(row) else { return nil }
        let cellID = NSUserInterfaceItemIdentifier("pennyworth-cell")
        let cell = (tableView.makeView(withIdentifier: cellID, owner: nil) as? ResultRowView) ?? ResultRowView()
        cell.identifier = cellID
        switch rows[row] {
        case .result(let result):
            cell.configure(with: result, position: row < 9 ? row + 1 : nil)
        case .action(let action):
            cell.configure(for: action.title, subtitle: "")
        case .openWith(url: let url, title: _):
            cell.configure(for: url.lastPathComponent, subtitle: url.path)
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        if row >= 0 {
            selectedIndex = row
        }
    }

    // MARK: - Actions execution

    private func showActions(for result: SearchResult) {
        let actions = ActionCatalog.actions(for: result.kind)
        rows = actions.map { .action($0) }
        mode = .actions(for: result)
        selectedIndex = 0
        hintLabel.stringValue = "Choose an action, or press Left to return"
        tableView.reloadData()
    }

    private func showOpenWith(for result: SearchResult) {
        let applications = executor?.applicationsThatCanOpen(result) ?? []
        var openWithRows: [RowModel] = applications.map { url in
            RowModel.openWith(url: url, title: FileManager.default.displayName(atPath: url.path))
        }
        openWithRows.append(.openWith(url: URL(fileURLWithPath: "/"), title: "Choose Other Application…"))
        rows = openWithRows
        mode = .openWith(for: result)
        selectedIndex = 0
        tableView.reloadData()
    }

    private func perform(action: AvailableAction, for result: SearchResult) {
        switch action.id {
        case .preview:
            QuickLookController.shared.togglePreview(for: URL(fileURLWithPath: result.targetValue))
        case .openWith:
            showOpenWith(for: result)
default:
            Task { @MainActor [weak self] in
                guard let self else { return }
                let outcome = await self.executor?.perform(action.id, for: result) ?? .failure("No executor configured")
                switch outcome {
                case .success, .acceptedDispatch:
                    self.recordSelection(result: result, actionID: action.id.rawValue)
                    if action.closeBehavior == .close {
                        self.onRequestDismiss?()
                    }
                case .failure(let message):
                    self.hintLabel.stringValue = message
                }
            }
        }
    }

    private func performOpenWith(_ url: URL, titled title: String, for result: SearchResult) {
        _ = title
        if url.path == "/" {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.application]
            panel.canChooseFiles = false
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            if panel.runModal() == .OK, let selectedURL = panel.url {
                Task { await executor?.openFile(result, withApplicationAt: selectedURL) }
            }
            recordSelection(result: result, actionID: "openWith")
            onRequestDismiss?()
            return
        }
        Task { await executor?.openFile(result, withApplicationAt: url) }
        recordSelection(result: result, actionID: "openWith")
        onRequestDismiss?()
    }

    private var lastRecordedEvent: (identity: String, at: Date)?

    private func recordSelection(result: SearchResult, actionID: String) {
        if result.kind == .url { return }
        if result.kind == .calculation { return }
        guard let parsed = coordinator?.lastParsed else { return }
        let identity = "\(result.providerID)|\(result.candidateID)|\(parsed.mode.rawValue)|\(actionID)"
        if let last = lastRecordedEvent,
            last.identity == identity,
            Date().timeIntervalSince(last.at) < 1.5
        {
            return
        }
        lastRecordedEvent = (identity, Date())
        let event = SelectionEvent(
            providerID: result.providerID,
            candidateID: result.candidateID,
            queryMode: parsed.mode.rawValue,
            normalizedQuery: parsed.normalizedText,
            actionID: actionID,
            selectedAt: Date()
        )
        selectionStore?.record(event)
    }

    private func flashError(_ message: String) {
        hintLabel.stringValue = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.hintLabel.stringValue = ""
        }
    }

    // MARK: - Command key shortcuts

    private func handleKeyEvent(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard view.window != nil, view.window?.isKeyWindow == true else { return false }
        guard modifiers.contains(.command), modifiers.intersection([.option, .control, .shift]).isEmpty else {
            return false
        }
        if (18...26).contains(Int(keyCode)) {
            let number = Int(keyCode) - 18 + 1
            guard rows.indices.contains(number - 1) else { return false }
            selectResultIndex(number - 1)
            handleReturn()
            return true
        }
        if keyCode == 36 { // Return
            revealSelectedIfPossible()
            return true
        }
        if keyCode == 8 { // C
            copySelected()
            return true
        }
        if keyCode == 16 { // Y
            quickLookSelected()
            return true
        }
        return false
    }

    private func selectResultIndex(_ index: Int) {
        guard rows.indices.contains(index) else { return }
        selectedIndex = index
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
    }

    private func revealSelectedIfPossible() {
        guard case .results = mode, let result = selectedResult() else { return }
        guard result.kind == .application || result.kind == .file || result.kind == .command else { return }
        _ = executor?.reveal(result)
        recordSelection(result: result, actionID: "reveal")
        onRequestDismiss?()
    }

    private func copySelected() {
        guard let result = selectedResult() else { return }
        if executor?.copy(result) == .success {
            recordSelection(result: result, actionID: "copy")
        }
    }

    private func quickLookSelected() {
        guard let result = selectedResult(), result.kind == .file else { return }
        QuickLookController.shared.togglePreview(for: URL(fileURLWithPath: result.targetValue))
    }
}