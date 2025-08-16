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
    
    /// Remove application from shield and database completely
    func removeApplicationCompletely(_ token: ApplicationToken) {
        print("[ShieldManager] Removing application completely from shield system")
        
        // Remove from discouraged selections
        discouragedSelections.applicationTokens.remove(token)
        
        // Remove from database using the more reliable byToken method
        let database = DataBase()
        database.removeApplicationProfile(byToken: token)
        print("[ShieldManager] Removed profile from database using token")
        
        // Apply updated shield settings
        shieldActivities()
        
        print("[ShieldManager] Application completely removed from shield system")
    }
    
    /// Sync ShieldManager with database to ensure consistency
    func syncWithDatabase() {
        print("[ShieldManager] Syncing with database...")
        
        let database = DataBase()
        let profiles = database.getApplicationProfiles()
        
        // Get all app tokens from database
        let databaseTokens = Set(profiles.values.map { $0.applicationToken })
        
        // Get current ShieldManager tokens
        let currentTokens = discouragedSelections.applicationTokens
        
        // Remove tokens that are no longer in database
        let tokensToRemove = currentTokens.subtracting(databaseTokens)
        for token in tokensToRemove {
            discouragedSelections.applicationTokens.remove(token)
            print("[ShieldManager] Removed token no longer in database: \(token)")
        }
        
        // Add tokens that are in database but not in ShieldManager
        let tokensToAdd = databaseTokens.subtracting(currentTokens)
        for token in tokensToAdd {
            discouragedSelections.applicationTokens.insert(token)
            print("[ShieldManager] Added token from database: \(token)")
        }
        
        // Apply updated shield settings
        shieldActivities()
        
        print("[ShieldManager] Sync completed. Total apps: \(discouragedSelections.applicationTokens.count)")
    }
    
    // Helper method to get current app count
    var currentAppCount: Int {
        return discouragedSelections.applicationTokens.count
    }
    
    func shieldActivities() {
        print("[ShieldManager] Starting shield activities update...")
        
        // Get current unlock sessions to know which apps should NOT be locked
        let database = DataBase()
        let activeUnlockSessions = database.getActiveUnlockSessions()
        let unlockedAppTokens = Set(activeUnlockSessions.values.map { $0.applicationToken })
        
        print("[ShieldManager] Found \(activeUnlockSessions.count) active unlock sessions")
        
        // Calculate which apps should be locked (discouraged - unlocked)
        let appsToLock = discouragedSelections.applicationTokens.subtracting(unlockedAppTokens)
        
        print("[ShieldManager] Apps to lock: \(appsToLock.count), Apps to keep unlocked: \(unlockedAppTokens.count)")
        
        // Clear to reset previous settings
        store.clearAllSettings()
                     
        let applications = appsToLock
        let categories = discouragedSelections.categoryTokens
        
        store.shield.applications = applications.isEmpty ? nil : applications
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
        
        print("[ShieldManager] Applied shield settings for \(applications.count) applications")
        
        // Debug: Print each application token
        for (index, token) in applications.enumerated() {
            print("[ShieldManager] App \(index + 1): \(token)")
        }
        
        // Debug: Print unlocked apps
        for (index, token) in unlockedAppTokens.enumerated() {
            print("[ShieldManager] Unlocked App \(index + 1): \(token)")
        }
    }
    
    // Helper method to check if an app is currently shielded
    func isAppShielded(_ token: ApplicationToken) -> Bool {
        return discouragedSelections.applicationTokens.contains(token)
    }
    
    // MARK: - Unlock Session Management (Phase 1.5 Bug Fix)
    
    /// Start an unlock session for an app
    func startUnlockSession(for token: ApplicationToken, duration: TimeInterval) {
        print("[ShieldManager] Starting unlock session for app, duration: \(duration) minutes")
        
        // Get app name from database or use a default
        let database = DataBase()
        let profiles = database.getApplicationProfiles()
        let appName = profiles.values.first { $0.applicationToken == token }?.applicationName ?? "Unknown App"
        
        // Create unlock session
        let unlockSession = UnlockSession(
            applicationToken: token,
            applicationName: appName,
            unlockDuration: duration
        )
        
        // Add to database
        database.addUnlockSession(unlockSession)
        
        // Update shield settings to reflect the unlock
        shieldActivities()
        
        print("[ShieldManager] Unlock session started for: \(appName)")
    }
    
    /// Check if an app is currently unlocked
    func isAppCurrentlyUnlocked(_ token: ApplicationToken) -> Bool {
        let database = DataBase()
        let activeSessions = database.getActiveUnlockSessions()
        return activeSessions.values.contains { $0.applicationToken == token }
    }
    
    /// Get current unlock sessions count
    var currentUnlockSessionsCount: Int {
        let database = DataBase()
        return database.getActiveUnlockSessions().count
    }
    
    /// End an unlock session and re-lock the app
    func endUnlockSession(for token: ApplicationToken) {
        print("[ShieldManager] Ending unlock session for app")
        
        let database = DataBase()
        let activeSessions = database.getActiveUnlockSessions()
        
        // Find and end the session
        if let session = activeSessions.values.first(where: { $0.applicationToken == token }) {
            database.endUnlockSession(session.id)
            print("[ShieldManager] Ended unlock session for: \(session.applicationName)")
            
            // Update shield settings to re-lock the app
            shieldActivities()
        }
    }
    
    /// End all unlock sessions (useful for cleanup)
    func endAllUnlockSessions() {
        print("[ShieldManager] Ending all unlock sessions")
        
        let database = DataBase()
        let activeSessions = database.getActiveUnlockSessions()
        
        for session in activeSessions.values {
            database.endUnlockSession(session.id)
        }
        
        // Update shield settings
        shieldActivities()
        
        print("[ShieldManager] Ended \(activeSessions.count) unlock sessions")
    }
    
    func unlockApplication(_ profile: ApplicationProfile) {
        // Start unlock session instead of just removing from shield
        startUnlockSession(for: profile.applicationToken, duration: 5.0) // Default 5 minutes
        print("[ShieldManager] Unlocked application: \(profile.applicationName)")
    }
    
    func unlockApplication(_ name: String) {
        print("[ShieldManager] Start UnLocking: \(name)")
        let db = DataBase()
        let profiles = db.getApplicationProfiles()
        for profile in profiles.values {
            if profile.applicationName == name {
                // Start unlock session instead of just removing from shield
                startUnlockSession(for: profile.applicationToken, duration: 5.0) // Default 5 minutes
                print("[ShieldManager] Unlocked application: \(profile.applicationName)")
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
