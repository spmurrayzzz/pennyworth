import AppKit

@MainActor
final class AppController {
    private let database: DatabaseStore
    private let selectionStore: SelectionStore
    private let webRegistry: WebSearchRegistry
    private let applicationIndex: ApplicationIndex
    private let actionExecutor: ActionExecutor
    private let coordinator: SearchCoordinator
    private let pennyworthWindow: PennyworthWindowController
    private let pennyworthViewController: PennyworthViewController
    private let statusItemController: StatusItemController

    private var hotKey: HotKeyController?

    init() {
        let fileManager = FileManager.default
        let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.local.pennyworth")
        let databaseURL = supportURL.appendingPathComponent("pennyworth.sqlite3")

        database = DatabaseStore(url: databaseURL)

        selectionStore = SelectionStore(database: database)
        webRegistry = WebSearchRegistry(database: database)

        applicationIndex = ApplicationIndex()
        actionExecutor = ActionExecutor()

        let fileService = FileMetadataService()
        let fileProvider = FileProvider(service: fileService)
        let applicationProvider = ApplicationProvider(index: applicationIndex)
        let calculatorProvider = CalculatorProvider()
        let commandProvider = CommandProvider()
        let webProvider = WebProvider(registry: webRegistry)

        coordinator = SearchCoordinator(
            applicationProvider: applicationProvider,
            fileProvider: fileProvider,
            webProvider: webProvider,
            calculatorProvider: calculatorProvider,
            commandProvider: commandProvider,
            applicationIndex: applicationIndex,
            selectionStore: selectionStore,
            webRegistry: webRegistry
        )

        pennyworthViewController = PennyworthViewController()
        pennyworthViewController.coordinator = coordinator
        pennyworthViewController.executor = actionExecutor
        pennyworthViewController.selectionStore = selectionStore

        self.pennyworthWindow = PennyworthWindowController(content: pennyworthViewController)

        coordinator.onResults = { [weak pennyworthViewController] results in
            Task { @MainActor in
                pennyworthViewController?.applyResults(results)
            }
        }

        statusItemController = StatusItemController(
            onOpenPennyworth: {},
            onOpenSettings: {},
            onQuit: { NSApp.terminate(nil) }
        )

        self.pennyworthWindow.setDismissHandler { [weak self] restoringForegroundApplication in
            self?.hidePennyworth(restoringForegroundApplication: restoringForegroundApplication)
        }
        statusItemController.setOpenHandlers(
            onOpenPennyworth: { [weak self] in self?.showPennyworth() },
            onOpenSettings: { [weak self] in self?.showSettings() }
        )
    }

    private func showPennyworth() {
        pennyworthWindow.show()
    }

    private func hidePennyworth(restoringForegroundApplication: Bool) {
        pennyworthWindow.hide(restoringForegroundApplication: restoringForegroundApplication)
    }

    func togglePennyworth() {
        pennyworthWindow.toggle()
    }

    func activate() {
        hotKey = HotKeyController(onToggle: { [weak self] in
            self?.togglePennyworth()
        })

        applicationIndex.start()

        Task { @MainActor in
            await database.open()
            await selectionStore.load()
            webRegistry.loadSelectionIfNeeded()
            coordinator.update(query: "", limit: AppSettings.resultLimit)
        }
    }


    private var settingsController: SettingsWindowController?

    func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(
                database: database,
                selectionStore: selectionStore,
                webRegistry: webRegistry
            )
        }
        settingsController?.showWindow(nil)
        NSApp.activate()
    }
}