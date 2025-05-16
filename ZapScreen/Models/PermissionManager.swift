import Foundation
import UserNotifications
import Network

class PermissionManager {
    static func requestNotificationAuthorization(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification authorization: \(error)")
            }
            print("Notification authorization granted: \(granted)")
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    static func requestLocalNetworkPermission(completion: @escaping (Bool) -> Void) {
        let monitor = NWPathMonitor()
        var didCallCompletion = false
        monitor.pathUpdateHandler = { path in
            if !didCallCompletion {
                didCallCompletion = true
                DispatchQueue.main.async {
                    completion(path.status == .satisfied)
                }
                monitor.cancel()
            }
        }
        let queue = DispatchQueue(label: "LocalNetworkPermission")
        monitor.start(queue: queue)
    }
}

