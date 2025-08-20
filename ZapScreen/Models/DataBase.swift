//
//  DataBase.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import Foundation
import ManagedSettings

struct DataBase {
    private let defaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
    private let shieldedAppsKey = "ZapShieldedApplications"
    private let unshieldedAppsKey = "ZapUnshieldedApplications"
    
    // MARK: - Shielded Applications (Permanently blocked)
    
    func getShieldedApplications() -> [UUID: ApplicationProfile] {
        guard let data = defaults?.data(forKey: shieldedAppsKey) else { return [:] }
        guard let decoded = try? JSONDecoder().decode([UUID: ApplicationProfile].self, from: data) else { return [:] }
        return decoded
    }
    
    func getShieldedApplication(id: UUID) -> ApplicationProfile? {
        return getShieldedApplications()[id]
    }
    
    func addShieldedApplication(_ application: ApplicationProfile) {
        var applications = getShieldedApplications()
        applications.updateValue(application, forKey: application.id)
        saveShieldedApplications(applications)
    }
    
    func saveShieldedApplications(_ applications: [UUID: ApplicationProfile]) {
        guard let encoded = try? JSONEncoder().encode(applications) else { return }
        defaults?.set(encoded, forKey: shieldedAppsKey)
    }
    
    func removeShieldedApplication(_ application: ApplicationProfile) {
        var applications = getShieldedApplications()
        applications.removeValue(forKey: application.id)
        saveShieldedApplications(applications)
    }
    
    // MARK: - Unshielded Applications (Temporarily unlocked)
    
    func getUnshieldedApplications() -> [UUID: UnshieldedApplication] {
        guard let data = defaults?.data(forKey: unshieldedAppsKey) else { return [:] }
        guard let decoded = try? JSONDecoder().decode([UUID: UnshieldedApplication].self, from: data) else { return [:] }
        return decoded
    }
    
    func getUnshieldedApplication(id: UUID) -> UnshieldedApplication? {
        return getUnshieldedApplications()[id]
    }
    
    func addUnshieldedApplication(_ application: UnshieldedApplication) {
        var applications = getUnshieldedApplications()
        applications.updateValue(application, forKey: application.id)
        saveUnshieldedApplications(applications)
    }
    
    func saveUnshieldedApplications(_ applications: [UUID: UnshieldedApplication]) {
        guard let encoded = try? JSONEncoder().encode(applications) else { return }
        defaults?.set(encoded, forKey: unshieldedAppsKey)
    }
    
    func removeUnshieldedApplication(_ application: UnshieldedApplication) {
        var applications = getUnshieldedApplications()
        applications.removeValue(forKey: application.id)
        saveUnshieldedApplications(applications)
    }
    
    // MARK: - Helper Methods for Unshielded Apps
    
    func getApplicationTokenForUnshieldedApp(_ unshieldedApp: UnshieldedApplication) -> ApplicationToken? {
        return unshieldedApp.shieldedAppToken
    }
    
//    func getApplicationProfileForUnshieldedApp(_ unshieldedApp: UnshieldedApplication) -> ApplicationProfile? {
//        // Get the ApplicationProfile from the referenced shielded app
//        if let shieldedApp = getShieldedApplication(id: unshieldedApp.shieldedAppToken) {
//            return shieldedApp
//        }
//        return nil
//    }
    
    // MARK: - Legacy Support (for backward compatibility)
    
//    func getApplicationProfiles() -> [UUID: ApplicationProfile] {
//        // Return both shielded and unshielded apps for backward compatibility
//        var allApps = getShieldedApplications()
//        let unshieldedApps = getUnshieldedApplications()
//        
//        for (_, unshieldedApp) in unshieldedApps {
//            if let appProfile = getApplicationProfileForUnshieldedApp(unshieldedApp) {
//                allApps[unshieldedApp.id] = appProfile
//            }
//        }
//        
//        return allApps
//    }
    
//    func getApplicationProfile(id: UUID) -> ApplicationProfile? {
//        // Check shielded apps first, then unshielded apps
//        if let shieldedApp = getShieldedApplication(id: id) {
//            return shieldedApp
//        }
//        
//        if let unshieldedApp = getUnshieldedApplication(id: id) {
//            return getApplicationProfileForUnshieldedApp(unshieldedApp)
//        }
//        
//        return nil
//    }
    
    func addApplicationProfile(_ application: ApplicationProfile) {
        // For backward compatibility, add as shielded app
        addShieldedApplication(application)
    }
    
    func saveApplicationProfiles(_ applications: [UUID: ApplicationProfile]) {
        // For backward compatibility, save as shielded apps
        saveShieldedApplications(applications)
    }
    
    func removeApplicationProfile(_ application: ApplicationProfile) {
        // Remove from both collections
        removeShieldedApplication(application)
        
        // Check if it exists in unshielded apps and remove it
        let unshieldedApps = getUnshieldedApplications()
        for (id, unshieldedApp) in unshieldedApps {
            if unshieldedApp.id == application.id {
                removeUnshieldedApplication(unshieldedApp)
                break
            }
        }
    }
    
    // MARK: - Utility Methods
    
    func isApplicationShielded(_ applicationToken: ApplicationToken) -> Bool {
        let shieldedApps = getShieldedApplications()
        return shieldedApps.values.contains { $0.applicationToken == applicationToken }
    }
    
    func isApplicationUnshielded(_ applicationToken: ApplicationToken) -> Bool {
        let unshieldedApps = getUnshieldedApplications()
        return unshieldedApps.values.contains { $0.shieldedAppToken == applicationToken }
    }
    
    func getApplicationByName(_ name: String) -> (ApplicationProfile, AppStatus)? {
        // Check shielded apps first
        let shieldedApps = getShieldedApplications()
        for (_, app) in shieldedApps {
            if app.applicationName == name {
                return (app, .shielded)
            }
        }
        
        // Check unshielded apps
        let unshieldedApps = getUnshieldedApplications()
        for (_, app) in unshieldedApps {
            if app.applicationName == name {
                let appProfile = ApplicationProfile(
                    applicationToken: app.shieldedAppToken,
                    applicationName: app.applicationName
                )
                return (appProfile, .unshielded)
            }
        }
        
        return nil
    }
    
    func cleanupExpiredUnshieldedApps() {
        let unshieldedApps = getUnshieldedApplications()
        let now = Date()
        var updatedApps = unshieldedApps
        
        for (id, app) in unshieldedApps {
            if app.expiryDate <= now {
                updatedApps.removeValue(forKey: id)
            }
        }
        
        if updatedApps.count != unshieldedApps.count {
            saveUnshieldedApplications(updatedApps)
        }
    }
}

// MARK: - Supporting Types

enum AppStatus {
    case shielded
    case unshielded
}
