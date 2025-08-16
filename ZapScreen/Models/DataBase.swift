//
//  DataBase.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import Foundation
import ManagedSettings

// New model for unlock sessions (replacing ApplicationProfile)
struct UnlockSession: Codable, Hashable, Identifiable {
    let id: UUID
    let applicationToken: ApplicationToken
    let applicationName: String
    let unlockStartTime: Date
    let unlockDuration: TimeInterval // in minutes
    let status: UnlockStatus
    let deviceActivityId: String? // for DeviceActivity monitoring
    
    init(applicationToken: ApplicationToken, applicationName: String, unlockDuration: TimeInterval, deviceActivityId: String? = nil) {
        self.id = UUID()
        self.applicationToken = applicationToken
        self.applicationName = applicationName
        self.unlockStartTime = Date()
        self.unlockDuration = unlockDuration
        self.status = .active
        self.deviceActivityId = deviceActivityId
    }
    
    // Custom initializer for creating expired sessions
    init(expiredFrom session: UnlockSession) {
        self.id = session.id
        self.applicationToken = session.applicationToken
        self.applicationName = session.applicationName
        self.unlockStartTime = session.unlockStartTime
        self.unlockDuration = session.unlockDuration
        self.status = .expired
        self.deviceActivityId = session.deviceActivityId
    }
}

// MARK: - UnlockStatus Enum
enum UnlockStatus: String, Codable, CaseIterable {
    case active = "active"           // Currently unlocked
    case expired = "expired"         // Time ran out
    case manually_ended = "manual"   // User ended early
}

struct DataBase {
    private let defaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
    private let applicationProfileKey = "ZapApplicationProfile"
    
    // New keys for unlock sessions and migration
    private let unlockSessionsKey = "UnlockSessions"
    private let migrationCompletedKey = "MigrationCompleted_v2"
    
    // MARK: - Migration Methods (Phase 1)
    
    /// Check if migration to new schema has been completed
    func isMigrationCompleted() -> Bool {
        return defaults?.bool(forKey: migrationCompletedKey) ?? false
    }
    
    /// Mark migration as completed
    private func markMigrationCompleted() {
        defaults?.set(true, forKey: migrationCompletedKey)
    }
    
    /// Migrate from old ApplicationProfile schema to new UnlockSession schema
    func migrateToNewSchema() {
        print("[DataBase] Starting migration to new schema...")
        
        // 1. Clear all existing incorrect data immediately
        defaults?.removeObject(forKey: applicationProfileKey)
        print("[DataBase] Cleared old ApplicationProfile data - starting fresh")
        
        // 2. Initialize new schema with empty unlock sessions
        let emptySessions: [UUID: UnlockSession] = [:]
        if let encoded = try? JSONEncoder().encode(emptySessions) {
            defaults?.set(encoded, forKey: unlockSessionsKey)
            print("[DataBase] Initialized new UnlockSessions schema")
        }
        
        // 3. Mark migration as completed
        markMigrationCompleted()
        print("[DataBase] Migration to new schema completed - clean slate achieved")
    }
    
    // MARK: - New UnlockSession Methods (Phase 1)
    
    /// Get all unlock sessions
    func getUnlockSessions() -> [UUID: UnlockSession] {
        guard let data = defaults?.data(forKey: unlockSessionsKey) else { return [:] }
        guard let decoded = try? JSONDecoder().decode([UUID: UnlockSession].self, from: data) else { return [:] }
        return decoded
    }
    
    /// Get only active unlock sessions
    func getActiveUnlockSessions() -> [UUID: UnlockSession] {
        let allSessions = getUnlockSessions()
        var activeSessions: [UUID: UnlockSession] = [:]
        
        for (id, session) in allSessions {
            if session.status == .active {
                activeSessions[id] = session
            }
        }
        
        return activeSessions
    }
    
    /// Add a new unlock session
    func addUnlockSession(_ session: UnlockSession) {
        var sessions = getUnlockSessions()
        sessions.updateValue(session, forKey: session.id)
        saveUnlockSessions(sessions)
        print("[DataBase] Added unlock session for: \(session.applicationName)")
    }
    
    /// Save all unlock sessions
    private func saveUnlockSessions(_ sessions: [UUID: UnlockSession]) {
        guard let encoded = try? JSONEncoder().encode(sessions) else { return }
        defaults?.set(encoded, forKey: unlockSessionsKey)
    }
    
    /// Get unlock session by DeviceActivity ID
    func getUnlockSession(activityId: String) -> UnlockSession? {
        let sessions = getUnlockSessions()
        return sessions.values.first { $0.deviceActivityId == activityId }
    }
    
    /// Mark unlock session as expired
    func expireUnlockSession(_ id: UUID) {
        var sessions = getUnlockSessions()
        if let session = sessions[id] {
            // Create expired session using custom initializer
            let expiredSession = UnlockSession(expiredFrom: session)
            sessions[id] = expiredSession
            saveUnlockSessions(sessions)
            print("[DataBase] Marked unlock session as expired for: \(session.applicationName)")
        }
    }
    
    /// End unlock session manually
    func endUnlockSession(_ id: UUID) {
        var sessions = getUnlockSessions()
        if let session = sessions[id] {
            sessions.removeValue(forKey: id)
            saveUnlockSessions(sessions)
            print("[DataBase] Manually ended unlock session for: \(session.applicationName)")
        }
    }
    
    // MARK: - Legacy ApplicationProfile Methods (Kept for backward compatibility during transition)
    
    func getApplicationProfiles() -> [UUID: ApplicationProfile] {
        guard let data = defaults?.data(forKey: applicationProfileKey) else { 
            print("[DataBase] No data found for key: \(applicationProfileKey)")
            return [:] 
        }
        
        guard let decoded = try? JSONDecoder().decode([UUID: ApplicationProfile].self, from: data) else { 
            print("[DataBase] Failed to decode application profiles from data")
            return [:] 
        }
        
        print("[DataBase] Successfully loaded \(decoded.count) application profiles from UserDefaults")
        return decoded
    }
    
    func getApplicationProfile(id: UUID) -> ApplicationProfile? {
        return getApplicationProfiles()[id]
    }
    
    /// Get application profile by application token
    func getApplicationProfile(byToken token: ApplicationToken) -> ApplicationProfile? {
        let profiles = getApplicationProfiles()
        return profiles.values.first { $0.applicationToken == token }
    }
    
    func addApplicationProfile(_ application: ApplicationProfile) {
        var applications = getApplicationProfiles()
        applications.updateValue(application, forKey: application.id)
        saveApplicationProfiles(applications)
    }
    
    func saveApplicationProfiles(_ applications: [UUID: ApplicationProfile]) {
        print("[DataBase] Saving \(applications.count) application profiles")
        
        guard let encoded = try? JSONEncoder().encode(applications) else { 
            print("[DataBase] Failed to encode application profiles")
            return 
        }
        
        defaults?.set(encoded, forKey: applicationProfileKey)
        print("[DataBase] Successfully saved \(applications.count) application profiles to UserDefaults")
    }
    
    func removeApplicationProfile(_ application: ApplicationProfile) {
        print("[DataBase] Attempting to remove profile: \(application.applicationName) with ID: \(application.id)")
        
        var applications = getApplicationProfiles()
        print("[DataBase] Current profiles in database: \(applications.count)")
        
        // Print all profile IDs for debugging
        for (id, profile) in applications {
            print("[DataBase] Profile ID: \(id), Name: \(profile.applicationName)")
        }
        
        // Find profile by applicationToken instead of ID (since IDs change)
        var profileToRemove: (UUID, ApplicationProfile)?
        for (id, profile) in applications {
            if profile.applicationToken == application.applicationToken {
                profileToRemove = (id, profile)
                break
            }
        }
        
        if let (id, profile) = profileToRemove {
            let removed = applications.removeValue(forKey: id)
            if removed != nil {
                print("[DataBase] Successfully removed profile: \(profile.applicationName) with ID: \(id)")
            } else {
                print("[DataBase] Failed to remove profile: \(profile.applicationName) - unexpected error")
            }
        } else {
            print("[DataBase] Failed to find profile with applicationToken: \(application.applicationToken)")
        }
        
        saveApplicationProfiles(applications)
        print("[DataBase] After removal - profiles in database: \(applications.count)")
    }
    
    /// Remove application profile by application token (more reliable)
    func removeApplicationProfile(byToken token: ApplicationToken) {
        print("[DataBase] Attempting to remove profile by token: \(token)")
        
        var applications = getApplicationProfiles()
        print("[DataBase] Current profiles in database: \(applications.count)")
        
        // Find profile by applicationToken
        var profileToRemove: (UUID, ApplicationProfile)?
        for (id, profile) in applications {
            if profile.applicationToken == token {
                profileToRemove = (id, profile)
                break
            }
        }
        
        if let (id, profile) = profileToRemove {
            let removed = applications.removeValue(forKey: id)
            if removed != nil {
                print("[DataBase] Successfully removed profile: \(profile.applicationName) with ID: \(id)")
            } else {
                print("[DataBase] Failed to remove profile: \(profile.applicationName) - unexpected error")
            }
        } else {
            print("[DataBase] Failed to find profile with applicationToken: \(token)")
        }
        
        saveApplicationProfiles(applications)
        print("[DataBase] After removal - profiles in database: \(applications.count)")
    }
}
