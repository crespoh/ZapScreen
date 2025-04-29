//
//  ShieldManager.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

class ShieldManager: ObservableObject {
    static let shared = ShieldManager()
    
    @Published var discouragedSelections = FamilyActivitySelection()
    
    private let store = ManagedSettingsStore()
    
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
    
    func saveLastBlockedApp(name: String, token: ApplicationToken) {
        print("Saved App name is " + name)
        let defaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
        defaults?.set(name, forKey: "lastBlockedAppName")
        defaults?.set(String(describing: token), forKey: "lastBlockedAppToken")
    }
    
    func unlockApplication(_ profile: ApplicationProfile) {
        store.shield.applications?.remove(profile.applicationToken)
    }
}
