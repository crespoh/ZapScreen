import UIKit
import FamilyControls
import ManagedSettings
import DeviceActivity
import UserNotifications
import Network

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let center = AuthorizationCenter.shared
    let store = ManagedSettingsStore()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Register for remote notifications
        application.registerForRemoteNotifications()
        
        return true
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
        if let action = content.userInfo["action"] as? String, action == "childUnlocked" {
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
        // Log the notification tap details
        print("Notification tapped:")
        print("Title: \(content.title)")
        print("Body: \(content.body)")
        print("User Info: \(content.userInfo)")
        
        // Handle any custom actions based on the notification
        if let bundleIdentifier = content.userInfo["bundleIdentifier"] as? String {
            print("App unlocked: \(bundleIdentifier)")
            // You can add additional handling here if needed
        }
        
        completionHandler()
    }
    
    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
} 
