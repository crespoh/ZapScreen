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
                store.shield.applications?.insert(app.applicationToken)
            } else {
                print("[ShieldManager] Skipping shield for temporarily unshielded app: \(app.applicationName)")
            }
        }
        print("[ShieldManager] shieldActivities() completed")
    }
    
    // MARK: - Shield Management
    
    func addApplicationToShield(_ application: ApplicationProfile) {
        print("[ShieldManager] Adding application to shield: \(application.applicationName)")
        database.addShieldedApplication(application)
        // Apply shield immediately
        store.shield.applications?.insert(application.applicationToken)
        print("[ShieldManager] Shield applied to: \(application.applicationName)")
        // Refresh data to trigger UI update
        refreshData()
    }
    
    func removeApplicationFromShield(_ application: ApplicationProfile) {
        database.removeShieldedApplication(application)
        // Remove shield immediately
        store.shield.applications?.remove(application.applicationToken)
        // Refresh data to trigger UI update
        refreshData()
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
                
                print("[ShieldManager] Successfully synced usage data to Supabase")
            } catch {
                print("[ShieldManager] Failed to sync usage data to Supabase: \(error)")
                // Could implement retry logic or offline queue here in future phases
            }
        }
        
        // Remove shield temporarily from store only
        store.shield.applications?.remove(application.applicationToken)
        
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
}
