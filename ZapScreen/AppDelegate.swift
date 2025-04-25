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
        
        // Request notification authorization
        requestNotificationAuthorization()
        requestLocalNetworkPermission()
        
//        print(AuthorizationCenter.shared.authorizationStatus)
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Register for remote notifications
        application.registerForRemoteNotifications()
        
        return true
    }
    
    private func requestLocalNetworkPermission() {
               let monitor = NWPathMonitor()
               monitor.pathUpdateHandler = { path in
                   if path.status == .satisfied {
                       print("Local network access granted")
                   } else {
                       print("Local network access denied")
                   }
               }
               let queue = DispatchQueue(label: "LocalNetworkPermission")
               monitor.start(queue: queue)
   }
    
    private func requestNotificationAuthorization() {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    print("Error requesting notification authorization: \(error)")
                }
                print("Notification authorization granted: \(granted)")
            }
    }
    
    // Handle successful registration
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
        
        // First check if device is already registered
        ZapScreenManager.shared.handleDeviceRegistration(deviceToken: token) { isParent in
            print("Device is parent: \(isParent)")
            // Store the parent status if needed
            UserDefaults.standard.set(isParent, forKey: "IsParentDevice")
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
        // Handle the notification when app is in foreground
        completionHandler([.list, .sound, .badge])
    }
    
    // Handle notification taps
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle the notification tap
        let userInfo = response.notification.request.content.userInfo
        print("Notification tapped with userInfo: \(userInfo)")
        completionHandler()
    }
    
    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
} 
