import UIKit
import FamilyControls
import ManagedSettings
import DeviceActivity
import UserNotifications
import Network
import SwiftData


class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let center = AuthorizationCenter.shared
    let store = ManagedSettingsStore()

    var applicationProfile: ApplicationProfile!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self
        // Register for remote notifications
        application.registerForRemoteNotifications()
        // Ensure deviceId is stored in group UserDefaults
        storeDeviceIdIfNeeded()
        storeDeviceInfo()
        // Check device registration on launch
        checkDeviceRegistrationAndHandleRole()
        return true
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        guard let command = userInfo["command"] as? String else {
            completionHandler(.noData)
            return
        }

        if command == "block_all_apps" {
            Task {
                await ShieldManager.shared.blockAll()
            }
        }

        completionHandler(.newData)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Check device registration when app enters foreground
        checkDeviceRegistrationAndHandleRole()
    }

    private func checkDeviceRegistrationAndHandleRole() {
        Task {
            await SupabaseManager.shared.restoreSessionFromAppGroup()
        }
        // Get deviceId from group UserDefaults (not deviceToken!)
        guard let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data"),
              let deviceId = groupDefaults.string(forKey: "ZapDeviceId") else {
            print("[AppDelegate] No deviceId found for registration check.")
            return
        }
        print("DeviceID: \(deviceId)")
        Task {
            do {
                // Check device registration in Supabase
                let exists = try await SupabaseManager.shared.deviceExists(deviceToken: "")
                if !exists {
                    print("[AppDelegate] Device is not registered. Removing selectedRole and isLoggedIn from group UserDefaults.")
                    groupDefaults.removeObject(forKey: "selectedRole")
                    groupDefaults.removeObject(forKey: "isLoggedIn")
                } else {
                    print("[AppDelegate] Device is registered in Supabase.")
                }
            } catch {
                print("[AppDelegate] Supabase device registration check failed: \(error)")
            }
        }
    }

    // Store deviceId in group UserDefaults if not already present
    private func storeDeviceIdIfNeeded() {
        guard let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") else { return }
        if groupDefaults.string(forKey: "ZapDeviceId") == nil,
           let deviceId = UIDevice.current.identifierForVendor?.uuidString {
            groupDefaults.set(deviceId, forKey: "ZapDeviceId")
            print("[AppDelegate] Stored deviceId to group UserDefaults: \(deviceId)")
        }
    }
    
    func storeDeviceInfo() {
        let deviceInfo = [
            "name": UIDevice.current.name,
            "model": UIDevice.current.model,
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        let data = try! JSONSerialization.data(withJSONObject: deviceInfo)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "DeviceRegistry",
            kSecAttrAccount as String: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: kCFBooleanTrue! // Sync via iCloud Keychain
        ]
        
        SecItemAdd(query as CFDictionary, nil)
    }
        
    // Handle successful registration
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
        
        // Store deviceToken in group UserDefaults for later use after login
        if let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") {
            groupDefaults.set(token, forKey: "DeviceToken")
            print("[AppDelegate] Device token saved to group UserDefaults: \(token)")
        } else {
            print("[AppDelegate] Failed to save device token to group UserDefaults.")
        }
    }
    
    // Handle registration failure
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
    
    // Handle incoming notifications when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Log the notification details
        let content = notification.request.content
        print("Received notification while in foreground:")
        print("Title: \(content.title)")
        print("Body: \(content.body)")
        print("User Info: \(content.userInfo)")
        
        // Show the notification even when the app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification taps
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        // Bridge to SwiftUI for navigation
        let content = response.notification.request.content
        if let action = content.userInfo["action"] as? String {
            switch action {
            case "childUnlock":
                handleChildUnlockedNotification(content: content)
            case "unlock":
                handleUnLockNotification(content: content)
            default:
                break
            }
        }
        // Log the notification tap details
        print("Notification tapped:")
        print("Title: \(content.title)")
        print("Body: \(content.body)")
        print("User Info: \(content.userInfo)")
        // Handle any custom actions based on the notification
        if let bundleIdentifier = content.userInfo["bundleIdentifier"] as? String {
            print("App unlocked: \(bundleIdentifier)")
        }
        completionHandler()
    }

    private func handleChildUnlockedNotification(content: UNNotificationContent) {
        // Set AppStorage flag to trigger navigation in group UserDefaults
        if let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") {
            groupDefaults.set(true, forKey: "zapShowRemoteLock")
            groupDefaults.synchronize()
        }
        // Save bundleIdentifier and childDeviceId to parent's group UserDefaults with keys starting with Zap
        if let bundleIdentifier = content.userInfo["bundleIdentifier"] as? String,
           let childDeviceId = content.userInfo["childDeviceId"] as? String {
            if let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") {
                groupDefaults.set(childDeviceId, forKey: "ZapChildDeviceId")
                groupDefaults.set(bundleIdentifier, forKey: "ZapLastUnlockedBundleIdentifier")
                groupDefaults.synchronize()
                print("[AppDelegate] Saved ZapChildDeviceId: \(childDeviceId), ZapLastUnlockedBundleIdentifier: \(bundleIdentifier) to group UserDefaults")
            }
        }
    }

    private func handleUnLockNotification(content: UNNotificationContent) {
        print("[AppDelegate] Received unlock action notification")
        guard let bundleIdentifier = content.userInfo["bundleIdentifier"] as? String else {
            print("[AppDelegate] No bundleIdentifier found in unlock notification")
            return
        }
        print("[AppDelegate] Locking app with bundleIdentifier: \(bundleIdentifier)")
        let shieldManager = ShieldManager.shared
        shieldManager.unlockApplication(bundleIdentifier)
        guard let minutes = content.userInfo["minutes"] as? Int else {
            print("[AppDelegate] No minutes found in unlock notification")
            return
        }
        let db = DataBase()
        let profiles = db.getApplicationProfiles()
        for profile in profiles {
            if profile.value.applicationName == bundleIdentifier {
                let applicationToken = profile.value.applicationToken
                createApplicationProfile(for: applicationToken, withName: bundleIdentifier)
                startMonitoring(minutes: minutes)
            }
        }
    }
    
    func createApplicationProfile(for application: ApplicationToken, withName name: String? = nil, withBundleId bundleid: String? = nil, withLDN ldn: String? = nil) {

        self.applicationProfile = ApplicationProfile(
            applicationToken: application,
            applicationName: name ?? "App \(application.hashValue)" // Use provided name or generate one
        )
        let dataBase = DataBase()
        dataBase.addApplicationProfile(self.applicationProfile)

    }
    
    func startMonitoring(minutes: Int) {
        print("Starting device activity monitoring for \(minutes)")
        let unlockTime = minutes
        let event: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            (DeviceActivityEvent.Name(self.applicationProfile.id.uuidString) as DeviceActivityEvent.Name): DeviceActivityEvent(
                applications: Set<ApplicationToken>([self.applicationProfile.applicationToken]),
                threshold: DateComponents(minute: unlockTime)
            )
        ]
        
        let intervalEnd = Calendar.current.dateComponents(
            [.hour, .minute, .second],
            from: Calendar.current.date(byAdding: .minute, value: unlockTime, to: Date.now) ?? Date.now
        )
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: intervalEnd,
            repeats: false
        )
         
        let center = DeviceActivityCenter()
        do {
            try center.startMonitoring(DeviceActivityName(self.applicationProfile.id.uuidString), during: schedule, events: event)
            print("Successfully started monitoring")
        } catch {
            print("Error monitoring schedule: \(error.localizedDescription)")
            print("Error monitoring schedule: \(error)")
        }
    }
    
    
    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
} 
