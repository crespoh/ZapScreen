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
    
    @Published var discouragedSelections = FamilyActivitySelection()
    
    private let store = ManagedSettingsStore()
    private let database = DataBase()
    
    private init() {}
    
    func shieldActivities() {
        // Clear to reset previous settings
        store.clearAllSettings()
                     
        let applications = discouragedSelections.applicationTokens
        let categories = discouragedSelections.categoryTokens
        
        store.shield.applications = applications.isEmpty ? nil : applications
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
    }
    
    // MARK: - Shield Management
    
    func addApplicationToShield(_ application: ApplicationProfile) {
        database.addShieldedApplication(application)
        // Apply shield immediately
        store.shield.applications?.insert(application.applicationToken)
    }
    
    func removeApplicationFromShield(_ application: ApplicationProfile) {
        database.removeShieldedApplication(application)
        // Remove shield immediately
        store.shield.applications?.remove(application.applicationToken)
    }
    
    // MARK: - Unshield Management
    
    func temporarilyUnlockApplication(_ application: ApplicationProfile, for durationMinutes: Int) {
        
        let unshieldedApp = UnshieldedApplication(
            shieldedAppToken: application.applicationToken,
            applicationName: application.applicationName,
            durationMinutes: durationMinutes
        )
        
        database.addUnshieldedApplication(unshieldedApp)
        
        // Remove shield temporarily
        store.shield.applications?.remove(application.applicationToken)
        
        // Start monitoring for expiry
        startUnshieldMonitoring(for: unshieldedApp)
    }
    
    func reapplyShieldToExpiredApp(_ unshieldedApp: UnshieldedApplication) {
        // Remove from unshielded collection
        database.removeUnshieldedApplication(unshieldedApp)
        
        // Get the original shielded app profile and reapply shield
//        if let originalAppProfile = database.getApplicationProfileForUnshieldedApp(unshieldedApp) {
//            addApplicationToShield(originalAppProfile)
//        }
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
    }
    
    func blockAll() {
        // Use FamilyActivityCategory enum directly for categories
        store.shield.applicationCategories = .all(except: []) // Block all categories
        store.shield.applications = nil // Or include everything
    }
}
