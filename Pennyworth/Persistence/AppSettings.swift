import Foundation

@MainActor
enum AppSettings {
    private static let defaults = UserDefaults.standard
    private static let resultLimitKey = "resultLimit"
    private static let defaultWebSearchKey = "defaultWebSearchID"

    static var resultLimit: Int {
        get {
            let stored = defaults.integer(forKey: resultLimitKey)
            return stored > 0 ? min(stored, 50) : 10
        }
        set {
            defaults.set(max(1, min(newValue, 50)), forKey: resultLimitKey)
        }
    }

    static var defaultWebSearchID: String? {
        get { defaults.string(forKey: defaultWebSearchKey) }
        set { defaults.set(newValue, forKey: defaultWebSearchKey) }
    }
}