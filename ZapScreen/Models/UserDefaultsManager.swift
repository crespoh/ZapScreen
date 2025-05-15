import Foundation

class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    private var defaults: UserDefaults
    
    private init() {
        // Initialize with standard UserDefaults first
        defaults = UserDefaults.standard
        
        // Try to initialize with app group UserDefaults
        if let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") {
            // Copy any existing values from standard to group defaults
            if let appName = defaults.string(forKey: "lastBlockedAppName") {
                groupDefaults.set(appName, forKey: "lastBlockedAppName")
            }
            if let appToken = defaults.string(forKey: "lastBlockedAppToken") {
                groupDefaults.set(appToken, forKey: "lastBlockedAppToken")
            }
            groupDefaults.synchronize()
            
            // Use group defaults if successful
            defaults = groupDefaults
        }
    }
    
    func setLastBlockedApp(name: String, token: String) {
        defaults.set(name, forKey: "lastBlockedAppName")
        defaults.set(token, forKey: "lastBlockedAppToken")
        defaults.synchronize()
    }
    
    func getLastBlockedApp() -> (name: String?, token: String?) {
        let name = defaults.string(forKey: "lastBlockedAppName")
        let token = defaults.string(forKey: "lastBlockedAppToken")
        return (name, token)
    }
    /// Returns all key-value pairs stored in the group UserDefaults (read-only).
    /// - Returns: A dictionary of all keys and their values.
    func allGroupUserDefaults() -> [String: Any] {
        guard let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") else { return [:] }
        return groupDefaults.dictionaryRepresentation().filter { $0.key != "AppleLanguages" && $0.key != "AppleLocale" }
    }
}

