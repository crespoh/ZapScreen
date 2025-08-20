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
        refreshData()
    }
    
    // MARK: - Data Refresh
    
    func refreshData() {
        shieldedApplications = getShieldedApplications()
        unshieldedApplications = getUnshieldedApplications()
    }
    
    func shieldActivities() {
        // Get all shielded apps from database
        let allShieldedApps = getShieldedApplications()
        
        // Get all temporarily unshielded apps
        let unshieldedApps = getUnshieldedApplications()
        
        // Create a set of tokens that are currently unshielded
        let unshieldedTokens = Set(unshieldedApps.map { $0.shieldedAppToken })
        
        // Only apply shield to apps that are NOT temporarily unshielded
        for app in allShieldedApps {
            if !unshieldedTokens.contains(app.applicationToken) {
                store.shield.applications?.insert(app.applicationToken)
            }
        }
    }
    
    // MARK: - Shield Management
    
    func addApplicationToShield(_ application: ApplicationProfile) {
        database.addShieldedApplication(application)
        // Apply shield immediately
        store.shield.applications?.insert(application.applicationToken)
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
}
