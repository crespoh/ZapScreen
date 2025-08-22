import Foundation
import UserNotifications
import SwiftUI

@MainActor
class ShieldNotificationService: ObservableObject {
    static let shared = ShieldNotificationService()
    
    @Published var isNotificationsEnabled = false
    @Published var notificationPreferences = NotificationPreferences()
    
    private init() {
        checkNotificationPermissions()
        loadPreferences()
    }
    
    // MARK: - Notification Types
    
    enum NotificationType: String, CaseIterable {
        case appShielded = "App Shielded"
        case appUnshielded = "App Unshielded"
        case appExpiring = "App Expiring Soon"
        case shieldRemoved = "Shield Removed"
        case childDeviceAdded = "Child Device Added"
        case usageLimitReached = "Usage Limit Reached"
        
        var title: String {
            switch self {
            case .appShielded: return "🛡️ App Shielded"
            case .appUnshielded: return "🔓 App Unshielded"
            case .appExpiring: return "⏰ App Expiring Soon"
            case .shieldRemoved: return "❌ Shield Removed"
            case .childDeviceAdded: return "👶 Child Device Added"
            case .usageLimitReached: return "⚠️ Usage Limit Reached"
            }
        }
        
        var description: String {
            switch self {
            case .appShielded: return "An app has been added to the shield list"
            case .appUnshielded: return "An app has been temporarily unshielded"
            case .appExpiring: return "An unshielded app is about to expire"
            case .shieldRemoved: return "An app has been removed from the shield list"
            case .childDeviceAdded: return "A new child device has been registered"
            case .usageLimitReached: return "A child has reached their usage limit"
            }
        }
    }
    
    // MARK: - Notification Preferences
    
    struct NotificationPreferences: Codable {
        var enabledTypes: Set<NotificationType> = Set(NotificationType.allCases)
        var quietHoursEnabled = false
        var quietHoursStart = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
        var quietHoursEnd = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
        var soundEnabled = true
        var badgeEnabled = true
        var previewEnabled = true
        
        // Custom coding keys to handle Set<NotificationType>
        enum CodingKeys: String, CodingKey {
            case enabledTypes
            case quietHoursEnabled
            case quietHoursStart
            case quietHoursEnd
            case soundEnabled
            case badgeEnabled
            case previewEnabled
        }
        
        init() {
            // Default initializer
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let enabledTypesArray = try container.decode([String].self, forKey: .enabledTypes)
            enabledTypes = Set(enabledTypesArray.compactMap { NotificationType(rawValue: $0) })
            quietHoursEnabled = try container.decode(Bool.self, forKey: .quietHoursEnabled)
            quietHoursStart = try container.decode(Date.self, forKey: .quietHoursStart)
            quietHoursEnd = try container.decode(Date.self, forKey: .quietHoursEnd)
            soundEnabled = try container.decode(Bool.self, forKey: .soundEnabled)
            badgeEnabled = try container.decode(Bool.self, forKey: .badgeEnabled)
            previewEnabled = try container.decode(Bool.self, forKey: .previewEnabled)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Array(enabledTypes.map { $0.rawValue }), forKey: .enabledTypes)
            try container.encode(quietHoursEnabled, forKey: .quietHoursEnabled)
            try container.encode(quietHoursStart, forKey: .quietHoursStart)
            try container.encode(quietHoursEnd, forKey: .quietHoursEnd)
            try container.encode(soundEnabled, forKey: .soundEnabled)
            try container.encode(badgeEnabled, forKey: .badgeEnabled)
            try container.encode(previewEnabled, forKey: .previewEnabled)
        }
    }
    
    // MARK: - Permission Management
    
    func checkNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isNotificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestNotificationPermissions() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            DispatchQueue.main.async {
                self.isNotificationsEnabled = granted
            }
            return granted
        } catch {
            print("[ShieldNotificationService] Failed to request notification permissions: \(error)")
            return false
        }
    }
    
    // MARK: - Notification Scheduling
    
    func scheduleNotification(for type: NotificationType, title: String, body: String, userInfo: [String: Any] = [:], delay: TimeInterval = 0) {
        guard isNotificationsEnabled && notificationPreferences.enabledTypes.contains(type) else { return }
        
        // Check quiet hours
        if notificationPreferences.quietHoursEnabled && isInQuietHours() {
            print("[ShieldNotificationService] Skipping notification during quiet hours")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = body
        content.sound = notificationPreferences.soundEnabled ? .default : nil
        content.badge = notificationPreferences.badgeEnabled ? 1 : nil
        content.userInfo = userInfo
        
        if !notificationPreferences.previewEnabled {
            content.body = "New shield activity"
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[ShieldNotificationService] Failed to schedule notification: \(error)")
            } else {
                print("[ShieldNotificationService] Notification scheduled successfully")
            }
        }
    }
    
    // MARK: - Specific Notification Methods
    
    func notifyAppShielded(appName: String, childName: String) {
        let body = "\(appName) has been shielded for \(childName)"
        scheduleNotification(
            for: .appShielded,
            title: "App Shielded",
            body: body,
            userInfo: ["appName": appName, "childName": childName, "action": "shielded"]
        )
    }
    
    func notifyAppUnshielded(appName: String, childName: String, duration: String) {
        let body = "\(appName) has been unshielded for \(childName) for \(duration)"
        scheduleNotification(
            for: .appUnshielded,
            title: "App Unshielded",
            body: body,
            userInfo: ["appName": appName, "childName": childName, "action": "unshielded", "duration": duration]
        )
    }
    
    func notifyAppExpiring(appName: String, childName: String, timeRemaining: String) {
        let body = "\(appName) will expire in \(timeRemaining) for \(childName)"
        scheduleNotification(
            for: .appExpiring,
            title: "App Expiring Soon",
            body: body,
            userInfo: ["appName": appName, "childName": childName, "action": "expiring", "timeRemaining": timeRemaining]
        )
    }
    
    func notifyShieldRemoved(appName: String, childName: String) {
        let body = "\(appName) has been removed from shield list for \(childName)"
        scheduleNotification(
            for: .shieldRemoved,
            title: "Shield Removed",
            body: body,
            userInfo: ["appName": appName, "childName": childName, "action": "removed"]
        )
    }
    
    func notifyChildDeviceAdded(childName: String, deviceId: String) {
        let body = "New child device registered: \(childName)"
        scheduleNotification(
            for: .childDeviceAdded,
            title: "Child Device Added",
            body: body,
            userInfo: ["childName": childName, "deviceId": deviceId, "action": "added"]
        )
    }
    
    func notifyUsageLimitReached(childName: String, appName: String) {
        let body = "\(childName) has reached usage limit for \(appName)"
        scheduleNotification(
            for: .usageLimitReached,
            title: "Usage Limit Reached",
            body: body,
            userInfo: ["childName": childName, "appName": appName, "action": "limit_reached"]
        )
    }
    
    // MARK: - Expiry Monitoring
    
    func scheduleExpiryReminders(for unshieldedApps: [SupabaseShieldSetting]) {
        for app in unshieldedApps {
            guard let expiryString = app.unlock_expiry,
                  let expiry = ISO8601DateFormatter().date(from: expiryString) else { continue }
            
            let timeUntilExpiry = expiry.timeIntervalSinceNow
            let fiveMinutesBefore = timeUntilExpiry - 300 // 5 minutes before
            
            if fiveMinutesBefore > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + fiveMinutesBefore) {
                    Task { @MainActor in
                        self.notifyAppExpiring(
                            appName: app.bundle_identifier,
                            childName: app.child_device_id,
                            timeRemaining: "5 minutes"
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Utility Methods
    
    private func isInQuietHours() -> Bool {
        let now = Date()
        let calendar = Calendar.current
        
        let startComponents = calendar.dateComponents([.hour, .minute], from: notificationPreferences.quietHoursStart)
        let endComponents = calendar.dateComponents([.hour, .minute], from: notificationPreferences.quietHoursEnd)
        
        let startTime = calendar.date(bySettingHour: startComponents.hour ?? 0, minute: startComponents.minute ?? 0, second: 0, of: now) ?? now
        let endTime = calendar.date(bySettingHour: endComponents.hour ?? 0, minute: endComponents.minute ?? 0, second: 0, of: now) ?? now
        
        // Handle overnight quiet hours
        if startTime > endTime {
            return now >= startTime || now <= endTime
        } else {
            return now >= startTime && now <= endTime
        }
    }
    
    // MARK: - Preferences Management
    
    func toggleNotificationType(_ type: NotificationType) {
        if notificationPreferences.enabledTypes.contains(type) {
            notificationPreferences.enabledTypes.remove(type)
        } else {
            notificationPreferences.enabledTypes.insert(type)
        }
        savePreferences()
    }
    
    func toggleQuietHours() {
        notificationPreferences.quietHoursEnabled.toggle()
        savePreferences()
    }
    
    func updateQuietHours(start: Date, end: Date) {
        notificationPreferences.quietHoursStart = start
        notificationPreferences.quietHoursEnd = end
        savePreferences()
    }
    
    func toggleSound() {
        notificationPreferences.soundEnabled.toggle()
        savePreferences()
    }
    
    func toggleBadge() {
        notificationPreferences.badgeEnabled.toggle()
        savePreferences()
    }
    
    func togglePreview() {
        notificationPreferences.previewEnabled.toggle()
        savePreferences()
    }
    
    private func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: "ShieldNotificationPreferences"),
           let preferences = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            notificationPreferences = preferences
        }
    }
    
    private func savePreferences() {
        if let data = try? JSONEncoder().encode(notificationPreferences) {
            UserDefaults.standard.set(data, forKey: "ShieldNotificationPreferences")
        }
    }
    
    // MARK: - Notification Center Management
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    func clearDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
