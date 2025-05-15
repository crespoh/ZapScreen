import Foundation

class UserDefaultsManager {
    static let shared = UserDefaultsManager()
 
    /// Returns all key-value pairs stored in the group UserDefaults (read-only).
    /// - Returns: A dictionary of all keys and their values.
    func allGroupUserDefaults() -> [String: Any] {
        guard let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") else { return [:] }
        return groupDefaults.dictionaryRepresentation().filter { $0.key != "AppleLanguages" && $0.key != "AppleLocale" }
    }
}
