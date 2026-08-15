import AppKit
import Foundation

@MainActor
final class ActionExecutor {
    enum Outcome: Equatable {
        case success
        case acceptedDispatch
        case failure(String)
    }

    private let workspace = NSWorkspace.shared

    func perform(_ action: ResultActionID, for result: SearchResult) async -> Outcome {
        switch action {
        case .open:
            return await open(result)
        case .reveal:
            return reveal(result)
        case .copy:
            return copy(result)
        case .preview:
            return .acceptedDispatch
        case .openWith:
            return .acceptedDispatch
        }
    }

    func open(_ result: SearchResult) async -> Outcome {
        switch result.kind {
        case .application, .command:
            let url = URL(fileURLWithPath: result.targetValue)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return .failure("The application is no longer available at its path.")
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            return await withCheckedContinuation { continuation in
                workspace.openApplication(at: url, configuration: configuration) { _, error in
                    if let error {
                        continuation.resume(returning: .failure(error.localizedDescription))
                    } else {
                        continuation.resume(returning: .success)
                    }
                }
            }
        case .file:
            let url = URL(fileURLWithPath: result.targetValue)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return .failure("The file is no longer available.")
            }
            return workspace.open(url) ? .success : .failure("The file could not be opened.")
        case .url:
            guard let url = URL(string: result.targetValue), URLPolicy.finalURL(from: result.targetValue) != nil else {
                return .failure("The URL is not valid.")
            }
            return workspace.open(url) ? .success : .failure("The URL could not be opened.")
        case .calculation:
            return copy(result)
        }
    }

    func reveal(_ result: SearchResult) -> Outcome {
        guard !result.targetValue.isEmpty else { return .failure("There is nothing to reveal.") }
        let url = URL(fileURLWithPath: result.targetValue)
        workspace.activateFileViewerSelecting([url])
        return .acceptedDispatch
    }

    func openFile(_ result: SearchResult, withApplicationAt appURL: URL) async -> Outcome {
        let url = URL(fileURLWithPath: result.targetValue)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failure("The file is no longer available.")
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        return await withCheckedContinuation { continuation in
            workspace.open([url], withApplicationAt: appURL, configuration: configuration) { _, error in
                if error != nil {
                    continuation.resume(returning: .acceptedDispatch)
                } else {
                    continuation.resume(returning: .success)
                }
            }
        }
    }

    func copy(_ result: SearchResult) -> Outcome {
        let value: String
        switch result.kind {
        case .url:
            value = result.targetValue
        case .calculation:
            value = result.accessoryText ?? result.targetValue
        default:
            value = result.targetValue
        }
        guard !value.isEmpty else { return .failure("There is nothing to copy.") }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        return .success
    }

    func applicationsThatCanOpen(_ result: SearchResult) -> [URL] {
        guard result.kind == .file else { return [] }
        let url = URL(fileURLWithPath: result.targetValue)
        return NSWorkspace.shared.urlsForApplications(toOpen: url)
    }
}