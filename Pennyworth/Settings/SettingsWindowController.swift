import AppKit
import SwiftUI
@preconcurrency import KeyboardShortcuts

@MainActor
final class SettingsWindowController: NSWindowController {
    private let model: SettingsModel

    init(database: DatabaseStore, selectionStore: SelectionStore, webRegistry: WebSearchRegistry) {
        let model = SettingsModel(database: database, selectionStore: selectionStore, webRegistry: webRegistry)
        self.model = model
        let rootView = SettingsRootView(model: model)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Pennyworth Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 560, height: 460))
        window.center()

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("unsupported")
    }
}

private struct SettingsRootView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        TabView {
            GeneralSettingsView(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
            WebSearchSettingsView(model: model)
                .tabItem { Label("Web", systemImage: "globe") }
        }
        .padding(20)
        .frame(width: 540, height: 430)
    }
}

private struct GeneralSettingsView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            LabeledContent("Toggle shortcut") {
                KeyboardShortcuts.Recorder("Toggle Pennyworth", name: .togglePennyworth)
            }
            .padding(.vertical, 4)

            Toggle("Launch at Login", isOn: $model.launchAtLogin)
                .onChange(of: model.launchAtLogin) { _, newValue in
                    model.updateLaunchAtLogin(newValue)
                }

            Stepper(value: $model.resultLimit, in: 1...50) {
                Text("Show up to \(model.resultLimit) results")
            }
            .onChange(of: model.resultLimit) { _, newValue in
                model.updateResultLimit(newValue)
            }

            Divider()

            Button("Reset Learned Ranking") {
                model.resetLearnedRanking()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct WebSearchSettingsView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            List {
                ForEach(model.webSearchList) { search in
                    WebSearchRow(
                        search: search,
                        isDefault: search.id == model.defaultSearchID,
                        onUpdate: { updated in model.updateSearch(updated) },
                        onDefault: { model.makeDefault(of: search) },
                        onDelete: { model.deleteSearch(id: search.id) }
                    )
                }
                .onMove { offsets, destination in
                    model.reorder(fromOffsets: offsets, toOffset: destination)
                }
            }
            .frame(minHeight: 220)

            HStack {
                Button("Add Search…") {
                    model.promptAddSearch()
                }
                Spacer()
                Text("Reorder with drag. {query} is the placeholder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .alert("Add a web search", isPresented: $model.isAddSheetPresented) {
            TextField("Name", text: $model.draftName)
            TextField("Keyword", text: $model.draftKeyword)
            TextField("URL template", text: $model.draftTemplate)
            Button("Add") { model.addSearch() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Use {query} as the placeholder.")
        }
    }
}

private struct WebSearchRow: View {
    let search: WebSearch
    let isDefault: Bool
    let onUpdate: (WebSearch) -> Void
    let onDefault: () -> Void
    let onDelete: () -> Void

    @State private var draftName = ""
    @State private var draftKeyword = ""
    @State private var draftEnabled = true
    @State private var draftTemplate = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Toggle("", isOn: $draftEnabled)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .frame(width: 24)
                TextField("Name", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                TextField("Keyword", text: $draftKeyword)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Button(isDefault ? "Default" : "Set Default") {
                    onDefault()
                }
                .disabled(isDefault)
                Spacer(minLength: 4)
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)

            }
            TextField("URL template", text: $draftTemplate)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))
        }
        .padding(.vertical, 4)
        .onAppear {
            draftName = search.name
            draftKeyword = search.keyword
            draftTemplate = search.urlTemplate
            draftEnabled = search.isEnabled
        }
        .onChange(of: draftName) { _, _ in commit() }
        .onChange(of: draftKeyword) { _, _ in commit() }
        .onChange(of: draftTemplate) { _, _ in commit() }
        .onChange(of: draftEnabled) { _, _ in commit() }
    }

    private func commit() {
        var updated = search
        updated.name = draftName
        updated.keyword = draftKeyword
        updated.urlTemplate = draftTemplate
        updated.updatedAt = Date()
        onUpdate(updated)
    }
}