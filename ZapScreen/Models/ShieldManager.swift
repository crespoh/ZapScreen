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
    static let shared = ShieldManager()
    
    @Published var discouragedSelections = FamilyActivitySelection()
    
    private let store = ManagedSettingsStore()
    
    private init() {}
    
    func addApplicationToShield(_ token: ApplicationToken) {
        discouragedSelections.applicationTokens.insert(token)
        print("[ShieldManager] Added application to shield. Total apps: \(discouragedSelections.applicationTokens.count)")
        shieldActivities()
    }
    
    func removeApplicationFromShield(_ token: ApplicationToken) {
        discouragedSelections.applicationTokens.remove(token)
        print("[ShieldManager] Removed application from shield. Total apps: \(discouragedSelections.applicationTokens.count)")
        shieldActivities()
    }
    
    // Helper method to get current app count
    var currentAppCount: Int {
        return discouragedSelections.applicationTokens.count
    }
    
    func shieldActivities() {
        // Clear to reset previous settings
        store.clearAllSettings()
                     
        let applications = discouragedSelections.applicationTokens
        let categories = discouragedSelections.categoryTokens
        
        store.shield.applications = applications.isEmpty ? nil : applications
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
        
        print("[ShieldManager] Applied shield settings for \(applications.count) applications")
        
        // Debug: Print each application token
        for (index, token) in applications.enumerated() {
            print("[ShieldManager] App \(index + 1): \(token)")
        }
    }
    
    // Helper method to check if an app is currently shielded
    func isAppShielded(_ token: ApplicationToken) -> Bool {
        return discouragedSelections.applicationTokens.contains(token)
    }
    
    func unlockApplication(_ profile: ApplicationProfile) {
        store.shield.applications?.remove(profile.applicationToken)
        print("[ShieldManager] Unlocked application: \(profile.applicationName)")
    }
    
    func unlockApplication(_ name: String) {
        print("[ShieldManager] Start UnLocking: \(name)")
        let db = DataBase()
        let profiles = db.getApplicationProfiles()
        for profile in profiles {
            if profile.value.applicationName == name {
                store.shield.applications?.remove(profile.value.applicationToken)
                print("[ShieldManager] Unlocked application: \(profile.value.applicationName)")
            }
        }
    }
    
    func blockAll() {
        // Use FamilyActivityCategory enum directly for categories
        store.shield.applicationCategories = .all(except: []) // Block all categories
        store.shield.applications = nil // Or include everything
        // store.shield.restriction = .none // Removed: No such property in ShieldSettings or ManagedSettingsStore
    }
    
}
