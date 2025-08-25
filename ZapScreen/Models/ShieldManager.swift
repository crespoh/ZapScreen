//
//  ShieldManager.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import SwiftUI
import SwiftData
import FamilyControls
import ManagedSettings
import DeviceActivity

class ShieldManager: ObservableObject {
    @Environment(\.modelContext) var modelContext
    static let shared = ShieldManager()
    
    @Published var shieldedApplications: [ApplicationProfile] = []
    @Published var unshieldedApplications: [UnshieldedApplication] = []
    
    private let store = ManagedSettingsStore()
    private let database = DataBase()
    
    private init() {
        print("[ShieldManager] Initializing ShieldManager")
        checkAuthorizationStatus()
        refreshData()
        
        // Initial sync to Supabase
        Task {
            await database.syncAllShieldSettingsToSupabase()
        }
        
        print("[ShieldManager] ShieldManager initialized with \(shieldedApplications.count) shielded apps")
    }
    
    // MARK: - Data Refresh
    
    func refreshData() {
        print("[ShieldManager] Refreshing data...")
        shieldedApplications = getShieldedApplications()
        unshieldedApplications = getUnshieldedApplications()
        print("[ShieldManager] Data refreshed - Shielded: \(shieldedApplications.count), Unshielded: \(unshieldedApplications.count)")
    }
    
    func shieldActivities() {
        print("[ShieldManager] shieldActivities() called")
        
        // Check authorization status first
        let center = AuthorizationCenter.shared
        let status = center.authorizationStatus
        print("[ShieldManager] Current authorization status: \(status)")
        
        // Check if store.shield.applications is nil
        if store.shield.applications == nil {
            print("[ShieldManager] ⚠️ store.shield.applications is nil in shieldActivities - initializing")
            store.shield.applications = Set<ApplicationToken>()
        }
        
        // Get all shielded apps from database
        let allShieldedApps = getShieldedApplications()
        print("[ShieldManager] Found \(allShieldedApps.count) shielded apps in database")
        
        // Get all temporarily unshielded apps
        let unshieldedApps = getUnshieldedApplications()
        print("[ShieldManager] Found \(unshieldedApps.count) unshielded apps")
        
        // Create a set of tokens that are currently unshielded
        let unshieldedTokens = Set(unshieldedApps.map { $0.shieldedAppToken })
        
        // Only apply shield to apps that are NOT temporarily unshielded
        for app in allShieldedApps {
            if !unshieldedTokens.contains(app.applicationToken) {
                print("[ShieldManager] Applying shield to: \(app.applicationName)")
                print("[ShieldManager] Token: \(app.applicationToken)")
                store.shield.applications?.insert(app.applicationToken)
                
                // Verify insertion
                if let currentShieldedApps = store.shield.applications {
                    let isInserted = currentShieldedApps.contains(app.applicationToken)
                    print("[ShieldManager] Shield verification for \(app.applicationName): \(isInserted)")
                }
            } else {
                print("[ShieldManager] Skipping shield for temporarily unshielded app: \(app.applicationName)")
            }
        }
        
        // Final verification
        if let finalShieldedApps = store.shield.applications {
            print("[ShieldManager] Final shielded apps count: \(finalShieldedApps.count)")
            for token in finalShieldedApps {
                print("[ShieldManager] Shielded token: \(token)")
            }
        }
        
        print("[ShieldManager] shieldActivities() completed")
    }
    
    // MARK: - Shield Management
    
    func addApplicationToShield(_ application: ApplicationProfile) {
        print("[ShieldManager] Adding application to shield: \(application.applicationName)")
        
        // Check if this is a parent device
        let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
        let selectedRole = groupDefaults?.string(forKey: "selectedRole")
        let isParentDevice = selectedRole == "Parent"
        
        // Check if this is the first app being added
        let isFirstApp = shieldedApplications.isEmpty
        
        if isParentDevice && isFirstApp {
            // Check authorization status before adding first app (only for parent devices)
            let center = AuthorizationCenter.shared
            let status = center.authorizationStatus
            
            print("[ShieldManager] Parent device - First app being added - Authorization status: \(status)")
            
            switch status {
            case .approved:
                print("[ShieldManager] ✅ Authorization approved - proceeding with shield")
                proceedWithAddingApp(application)
                
            case .denied:
                print("[ShieldManager] ❌ Authorization denied - cannot add app to shield")
                // Note: In a real app, you might want to show an alert to the user
                // For now, we'll just log the error
                return
                
            case .notDetermined:
                print("[ShieldManager] ⚠️ Authorization not determined - requesting authorization")
                Task {
                    do {
                        try await center.requestAuthorization(for: .individual)
                        print("[ShieldManager] ✅ Authorization request completed")
                        
                        // Check status again after request
                        let newStatus = center.authorizationStatus
                        if newStatus == .approved {
                            print("[ShieldManager] ✅ Authorization approved after request - proceeding with shield")
                            await MainActor.run {
                                proceedWithAddingApp(application)
                            }
                        } else {
                            print("[ShieldManager] ❌ Authorization still not approved after request")
                            // Note: In a real app, you might want to show an alert to the user
                        }
                    } catch {
                        print("[ShieldManager] ❌ Authorization request failed: \(error)")
                        // Note: In a real app, you might want to show an alert to the user
                    }
                }
                return
                
            @unknown default:
                print("[ShieldManager] ❓ Unknown authorization status - proceeding with caution")
                proceedWithAddingApp(application)
            }
        } else {
            // Not a parent device or not the first app, proceed normally
            if !isParentDevice {
                print("[ShieldManager] Child device - proceeding with shield without authorization check")
            } else {
                print("[ShieldManager] Not the first app - proceeding with shield")
            }
            proceedWithAddingApp(application)
        }
    }
    
    private func proceedWithAddingApp(_ application: ApplicationProfile) {
        print("[ShieldManager] Proceeding with adding app to shield: \(application.applicationName)")
        print("[ShieldManager] Application token: \(application.applicationToken)")
        
        // Add to database first
        database.addShieldedApplication(application)
        print("[ShieldManager] ✅ App added to database")
        
        // Check if store.shield.applications is nil
        if store.shield.applications == nil {
            print("[ShieldManager] ⚠️ store.shield.applications is nil - initializing")
            store.shield.applications = Set<ApplicationToken>()
        }
        
        // Apply shield immediately
        print("[ShieldManager] Attempting to insert token into shield...")
        store.shield.applications?.insert(application.applicationToken)
        
        // Verify the insertion
        if let currentShieldedApps = store.shield.applications {
            let isInserted = currentShieldedApps.contains(application.applicationToken)
            print("[ShieldManager] Shield verification - Token inserted: \(isInserted)")
            print("[ShieldManager] Current shielded apps count: \(currentShieldedApps.count)")
        } else {
            print("[ShieldManager] ❌ store.shield.applications is still nil after initialization")
        }
        
        print("[ShieldManager] Shield applied to: \(application.applicationName)")
        
        // Send notification
        if let childName = getCurrentChildName() {
            // TODO: Re-enable when notification service is properly imported
            // ShieldNotificationService.shared.notifyAppShielded(
            //     appName: application.applicationName,
            //     childName: childName
            // )
            print("[ShieldManager] Would send notification: App \(application.applicationName) shielded for \(childName)")
        }
        
        // Sync to Supabase
        Task {
            await database.syncShieldedApplicationsToSupabase()
        }
        
        // Refresh data to trigger UI update
        refreshData()
    }
    
    func removeApplicationFromShield(_ application: ApplicationProfile) {
        database.removeShieldedApplication(application)
        // Remove shield immediately
        store.shield.applications?.remove(application.applicationToken)
        
        // Send notification
        if let childName = getCurrentChildName() {
            // TODO: Re-enable when notification service is properly imported
            // ShieldNotificationService.shared.notifyShieldRemoved(
            //     appName: application.applicationName,
            //     childName: childName
            // )
            print("[ShieldManager] Would send notification: App \(application.applicationName) shield removed for \(childName)")
        }
        
        // Delete from Supabase first, then sync remaining apps
        Task {
            // Get current device info for deletion
            let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
            if let deviceId = groupDefaults?.string(forKey: "ZapDeviceId") {
                
                // Delete from Supabase by app bundle identifier
                do {
                    _ = try await SupabaseManager.shared.deleteShieldSettingByApp(
                        bundleIdentifier: application.applicationName.lowercased().replacingOccurrences(of: " ", with: "_"),
                        childDeviceId: deviceId
                    )
                    print("[ShieldManager] Successfully deleted shield setting for \(application.applicationName) from Supabase")
                } catch {
                    print("[ShieldManager] Failed to delete shield setting from Supabase: \(error)")
                }
            }
            
            // Also sync remaining shielded apps to ensure consistency
            await database.syncShieldedApplicationsToSupabase()
        }
        
        // Refresh data to trigger UI update
        refreshData()
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentChildName() -> String? {
        let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
        return groupDefaults?.string(forKey: "DeviceName")
    }
    
    // MARK: - Unshield Management
    
    func temporarilyUnlockApplication(_ application: ApplicationProfile, for durationMinutes: Int) {
        
        let unshieldedApp = UnshieldedApplication(
            shieldedAppToken: application.applicationToken,
            applicationName: application.applicationName,
            durationMinutes: durationMinutes
        )
        
        // Add to unshielded collection (keep in shielded collection for history)
        database.addUnshieldedApplication(unshieldedApp)
        
        // Update usage statistics locally
        database.updateUsageStatistics(for: application.applicationName, durationMinutes: durationMinutes)
        
        // Create usage record for Supabase sync
        let record = UsageRecord(
            appName: application.applicationName,
            applicationToken: application.applicationToken,
            durationMinutes: durationMinutes
        )
        
        // Sync to Supabase (both record and updated statistics)
        Task {
            do {
                // Sync individual record for detailed tracking
                try await SupabaseManager.shared.syncUsageRecords([record])
                
                // Also sync updated statistics for quick access
                let statistics = database.getUsageStatistics()
                try await SupabaseManager.shared.syncUsageStatistics(Array(statistics.values))
                
                // Sync shield settings to Supabase
                await database.syncUnshieldedApplicationsToSupabase()
                
                print("[ShieldManager] Successfully synced usage data and shield settings to Supabase")
            } catch {
                print("[ShieldManager] Failed to sync usage data to Supabase: \(error)")
                // Could implement retry logic or offline queue here in future phases
            }
        }
        
        // Remove shield temporarily from store only
        store.shield.applications?.remove(application.applicationToken)
        
        // Send notification
        if let childName = getCurrentChildName() {
            let durationText = "\(durationMinutes) minutes"
            // TODO: Re-enable when notification service is properly imported
            // ShieldNotificationService.shared.notifyAppUnshielded(
            //     appName: application.applicationName,
            //     childName: childName,
            //     duration: durationText
            // )
            print("[ShieldManager] Would send notification: App \(application.applicationName) unshielded for \(durationText) for \(childName)")
        }
        
        // Start monitoring for expiry
        startUnshieldMonitoring(for: unshieldedApp)
        
        // Refresh data to trigger UI update
        refreshData()
    }
    
    func reapplyShieldToExpiredApp(_ unshieldedApp: UnshieldedApplication) {
        // Remove from unshielded collection
        database.removeUnshieldedApplication(unshieldedApp)
        
        // Create the original app profile and re-add to shielded collection
        let originalAppProfile = ApplicationProfile(
            applicationToken: unshieldedApp.shieldedAppToken,
            applicationName: unshieldedApp.applicationName
        )
        
        // Re-add to shielded collection
        addApplicationToShield(originalAppProfile)
        
        // Sync to Supabase
        Task {
            await database.syncAllShieldSettingsToSupabase()
        }
        
        // Refresh data to trigger UI update
        refreshData()
    }
    
    // MARK: - Legacy Support
    
    func unlockApplication(_ profile: ApplicationProfile) {
        // For backward compatibility, temporarily unlock for 5 minutes
        temporarilyUnlockApplication(profile, for: 5)
    }
    
    func unlockApplication(_ name: String) {
        print("[ShieldManager] Start UnLocking")
        
        if let (appProfile, status) = database.getApplicationByName(name) {
            switch status {
            case .shielded:
                // Temporarily unlock for 5 minutes
                temporarilyUnlockApplication(appProfile, for: 5)
            case .unshielded:
                print("[ShieldManager] App is already unshielded")
            }
        } else {
            print("[ShieldManager] App not found in database")
        }
    }
    
    // MARK: - Monitoring
    
    private func startUnshieldMonitoring(for unshieldedApp: UnshieldedApplication) {
        // Get the ApplicationToken from the referenced shielded app
        let applicationToken = unshieldedApp.shieldedAppToken
        
        let event: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            (DeviceActivityEvent.Name(unshieldedApp.id.uuidString) as DeviceActivityEvent.Name): DeviceActivityEvent(
                applications: Set<ApplicationToken>([applicationToken]),
                threshold: DateComponents(minute: unshieldedApp.durationMinutes)
            )
        ]
        
        let intervalEnd = Calendar.current.dateComponents(
            [.hour, .minute, .second],
            from: unshieldedApp.expiryDate
        )
        
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: intervalEnd,
            repeats: false
        )
         
        let center = DeviceActivityCenter()
        do {
            try center.startMonitoring(
                DeviceActivityName(unshieldedApp.id.uuidString),
                during: schedule,
                events: event
            )
            print("[ShieldManager] Successfully started monitoring for app: \(unshieldedApp.applicationName)")
        } catch {
            print("[ShieldManager] Error monitoring schedule: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    
    func getShieldedApplications() -> [ApplicationProfile] {
        return Array(database.getShieldedApplications().values)
    }
    
    func getUnshieldedApplications() -> [UnshieldedApplication] {
        return Array(database.getUnshieldedApplications().values)
    }
    
    func isApplicationAlreadyShielded(_ application: ApplicationProfile) -> Bool {
        return shieldedApplications.contains { shieldedApp in
            shieldedApp.applicationToken.hashValue == application.applicationToken.hashValue
        }
    }
    
    func cleanupExpiredUnshieldedApps() {
        database.cleanupExpiredUnshieldedApps()
        // Refresh data to trigger UI update
        refreshData()
    }
    
    func blockAll() {
        // Use FamilyActivityCategory enum directly for categories
        store.shield.applicationCategories = .all(except: []) // Block all categories
        store.shield.applications = nil // Or include everything
    }
    
    // Debug function to check authorization status
    func checkAuthorizationStatus() {
        let center = AuthorizationCenter.shared
        let status = center.authorizationStatus
        print("[ShieldManager] Family Controls Authorization Status: \(status)")
        
        switch status {
        case .approved:
            print("[ShieldManager] ✅ Authorization approved - shielding should work")
        case .denied:
            print("[ShieldManager] ❌ Authorization denied - shielding will not work")
        case .notDetermined:
            print("[ShieldManager] ⚠️ Authorization not determined - need to request authorization")
        @unknown default:
            print("[ShieldManager] ❓ Unknown authorization status")
        }
    }
    
    // Debug function to check current shield status
    func checkCurrentShieldStatus() {
        print("[ShieldManager] ====== Current Shield Status ======")
        
        // Check authorization
        let center = AuthorizationCenter.shared
        let status = center.authorizationStatus
        print("[ShieldManager] Authorization Status: \(status)")
        
        // Check store.shield.applications
        if let shieldedApps = store.shield.applications {
            print("[ShieldManager] Store Shielded Apps Count: \(shieldedApps.count)")
            for token in shieldedApps {
                print("[ShieldManager] Shielded Token: \(token)")
            }
        } else {
            print("[ShieldManager] ❌ store.shield.applications is nil")
        }
        
        // Check database
        let dbShieldedApps = getShieldedApplications()
        print("[ShieldManager] Database Shielded Apps Count: \(dbShieldedApps.count)")
        for app in dbShieldedApps {
            print("[ShieldManager] Database App: \(app.applicationName) - Token: \(app.applicationToken)")
        }
        
        // Check published properties
        print("[ShieldManager] Published Shielded Apps Count: \(shieldedApplications.count)")
        print("[ShieldManager] Published Unshielded Apps Count: \(unshieldedApplications.count)")
        
        // Check if shield is actually working
        checkShieldEffectiveness()
        
        print("[ShieldManager] ====== Shield Status Complete ======")
    }
    
    // Debug function to check if shield is actually working
    private func checkShieldEffectiveness() {
        print("[ShieldManager] ====== Shield Effectiveness Check ======")
        
        // Check if store.shield.applications is properly set
        if let shieldedApps = store.shield.applications {
            print("[ShieldManager] ✅ Store.shield.applications is set with \(shieldedApps.count) apps")
            
            // Check if the apps are actually being blocked
            for token in shieldedApps {
                print("[ShieldManager] Checking if token \(token) is being blocked...")
                
                // Try to check if the app is accessible (this is limited in iOS)
                // We can only verify that the token is in the shield set
                if shieldedApps.contains(token) {
                    print("[ShieldManager] ✅ Token \(token) is in shield set - should be blocked")
                } else {
                    print("[ShieldManager] ❌ Token \(token) is NOT in shield set")
                }
            }
        } else {
            print("[ShieldManager] ❌ Store.shield.applications is nil - shield not working")
        }
        
        // Check if there are any temporarily unshielded apps that might be interfering
        let unshieldedApps = getUnshieldedApplications()
        if !unshieldedApps.isEmpty {
            print("[ShieldManager] ⚠️ Found \(unshieldedApps.count) temporarily unshielded apps:")
            for app in unshieldedApps {
                print("[ShieldManager] - \(app.applicationName) (Expired: \(app.isExpired))")
            }
        }
        
        print("[ShieldManager] ====== Shield Effectiveness Complete ======")
    }
}
