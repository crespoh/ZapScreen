import UIKit
import FamilyControls
import ManagedSettings
import DeviceActivity

class AppDelegate: UIResponder, UIApplicationDelegate {
    let center = AuthorizationCenter.shared
    let store = ManagedSettingsStore()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Request Family Controls authorization
        Task {
            do {
                try await center.requestAuthorization(for: .individual)
            } catch {
                print("Failed to request authorization: \(error)")
            }
        }
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
} 