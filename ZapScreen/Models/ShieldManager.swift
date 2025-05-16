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
    @Query private var appTokenNames: [AppTokenName]
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
    
    func unlockApplication(_ profile: ApplicationProfile) {
        store.shield.applications?.remove(profile.applicationToken)
    }
    
    func unlockApplication(_ name: String) {
        print("[ShieldManager] Start UnLocking")
        let db = DataBase()
        let profiles = db.getApplicationProfiles()
        for profile in profiles {
            if profile.value.applicationName == name {
                store.shield.applications?.remove(profile.value.applicationToken)
            }
        }
//        for appTokenName in appTokenNames {
//            if appTokenName.name == name {
//                print("[ShieldManager] Shield Up!")
//                store.shield.applications?.insert(appTokenName.token)
//            }
//        }
    }
    
}
