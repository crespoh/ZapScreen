//
//  ShieldSettingsModels.swift
//  ZapScreen
//
//  Created for Phase 1: Child Shield Settings to Supabase
//

import Foundation
import ManagedSettings

// MARK: - Supabase Shield Settings Models

/// Model for storing child shield settings in Supabase
struct SupabaseShieldSetting: Codable, Identifiable {
    let id: String
    let user_account_id: String
    let child_device_id: String
    let child_name: String
    let app_name: String
    let bundle_identifier: String
    let is_shielded: Bool
    let shield_type: String // "permanent" or "temporary"
    let unlock_expiry: String? // ISO8601 date string
    let created_at: String
    let updated_at: String
    
    /// Convert unlock_expiry string to Date
    var unlockExpiryDate: Date? {
        guard let unlock_expiry = unlock_expiry else { return nil }
        return ISO8601DateFormatter().date(from: unlock_expiry)
    }
    
    /// Convert created_at string to Date
    var createdAtDate: Date? {
        ISO8601DateFormatter().date(from: created_at)
    }
    
    /// Convert updated_at string to Date
    var updatedAtDate: Date? {
        ISO8601DateFormatter().date(from: updated_at)
    }
    
    /// Check if the shield setting is expired (for temporary shields)
    var isExpired: Bool {
        guard let expiryDate = unlockExpiryDate else { return false }
        return Date() > expiryDate
    }
    
    /// Get remaining time for temporary shields
    var remainingTime: TimeInterval? {
        guard let expiryDate = unlockExpiryDate else { return nil }
        let remaining = expiryDate.timeIntervalSince(Date())
        return remaining > 0 ? remaining : 0
    }
    
    /// Get remaining minutes for temporary shields
    var remainingMinutes: Int? {
        guard let remaining = remainingTime else { return nil }
        return Int(remaining / 60)
    }
    
    /// Get formatted remaining time string
    var formattedRemainingTime: String? {
        guard let minutes = remainingMinutes else { return nil }
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMins = minutes % 60
            if remainingMins == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMins)m"
            }
        }
    }
}

/// Model for inserting/updating child shield settings in Supabase
struct SupabaseShieldSettingInsert: Encodable {
    let user_account_id: String
    let child_device_id: String
    let child_name: String
    let app_name: String
    let bundle_identifier: String
    let is_shielded: Bool
    let shield_type: String
    let unlock_expiry: String?
    
    /// Initialize with ApplicationProfile for shielded apps
    init(applicationProfile: ApplicationProfile, 
         userAccountId: String, 
         childDeviceId: String, 
         childName: String) {
        self.user_account_id = userAccountId
        self.child_device_id = childDeviceId
        self.child_name = childName
        self.app_name = applicationProfile.applicationName
        self.bundle_identifier = applicationProfile.applicationToken.id
        self.is_shielded = true
        self.shield_type = "permanent"
        self.unlock_expiry = nil
    }
    
    /// Initialize with UnshieldedApplication for temporarily unshielded apps
    init(unshieldedApp: UnshieldedApplication, 
         userAccountId: String, 
         childDeviceId: String, 
         childName: String) {
        self.user_account_id = userAccountId
        self.child_device_id = childDeviceId
        self.child_name = childName
        self.app_name = unshieldedApp.applicationName
        self.bundle_identifier = unshieldedApp.shieldedAppToken.id
        self.is_shielded = false
        self.shield_type = "temporary"
        
        // Convert expiry date to ISO8601 string
        let formatter = ISO8601DateFormatter()
        self.unlock_expiry = formatter.string(from: unshieldedApp.expiryDate)
    }
    
    /// Initialize with custom values
    init(userAccountId: String, 
         childDeviceId: String, 
         childName: String, 
         appName: String, 
         bundleIdentifier: String, 
         isShielded: Bool, 
         shieldType: String, 
         unlockExpiry: Date? = nil) {
        self.user_account_id = userAccountId
        self.child_device_id = childDeviceId
        self.child_name = childName
        self.app_name = appName
        self.bundle_identifier = bundleIdentifier
        self.is_shielded = isShielded
        self.shield_type = shieldType
        
        if let expiry = unlockExpiry {
            let formatter = ISO8601DateFormatter()
            self.unlock_expiry = formatter.string(from: expiry)
        } else {
            self.unlock_expiry = nil
        }
    }
}

// MARK: - Shield Settings Summary Models

/// Summary of shield settings for a child device
struct ChildShieldSummary: Codable, Identifiable {
    let child_device_id: String
    let child_name: String
    let total_apps: Int
    let shielded_apps: Int
    let unshielded_apps: Int
    let last_updated: String
    
    var id: String { child_device_id }
    
    /// Convert last_updated string to Date
    var lastUpdatedDate: Date? {
        ISO8601DateFormatter().date(from: last_updated)
    }
    
    /// Calculate percentage of shielded apps
    var shieldedPercentage: Double {
        guard total_apps > 0 else { return 0 }
        return Double(shielded_apps) / Double(total_apps) * 100
    }
}

/// Summary of all children's shield settings for a parent
struct ParentShieldSummary: Codable {
    let total_children: Int
    let total_apps: Int
    let total_shielded: Int
    let total_unshielded: Int
    let children_summaries: [ChildShieldSummary]
    
    /// Calculate overall shielded percentage
    var overallShieldedPercentage: Double {
        guard total_apps > 0 else { return 0 }
        return Double(total_shielded) / Double(total_apps) * 100
    }
    
    /// Get summary for a specific child
    func summaryForChild(_ childDeviceId: String) -> ChildShieldSummary? {
        return children_summaries.first { $0.child_device_id == childDeviceId }
    }
}

// MARK: - Shield Settings Change Models

/// Model for tracking shield setting changes
struct ShieldSettingChange: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let child_device_id: String
    let child_name: String
    let app_name: String
    let bundle_identifier: String
    let change_type: ShieldChangeType
    let previous_status: String?
    let new_status: String
    let duration_minutes: Int?
    
    enum ShieldChangeType: String, Codable, CaseIterable {
        case added = "added"
        case removed = "removed"
        case temporarilyUnlocked = "temporarily_unlocked"
        case reShielded = "re_shielded"
        case expired = "expired"
        
        var displayName: String {
            switch self {
            case .added: return "Added to Shield"
            case .removed: return "Removed from Shield"
            case .temporarilyUnlocked: return "Temporarily Unlocked"
            case .reShielded: return "Re-shielded"
            case .expired: return "Expired"
            }
        }
        
        var icon: String {
            switch self {
            case .added: return "shield.fill"
            case .removed: return "shield.slash"
            case .temporarilyUnlocked: return "lock.open"
            case .reShielded: return "shield"
            case .expired: return "clock.badge.exclamationmark"
            }
        }
        
        var color: String {
            switch self {
            case .added: return "red"
            case .removed: return "green"
            case .temporarilyUnlocked: return "orange"
            case .reShielded: return "blue"
            case .expired: return "gray"
            }
        }
    }
}

// MARK: - Shield Settings Filter Models

/// Filter options for shield settings
struct ShieldSettingsFilter {
    var showShielded: Bool = true
    var showUnshielded: Bool = true
    var showPermanent: Bool = true
    var showTemporary: Bool = true
    var searchText: String = ""
    var sortBy: ShieldSortOption = .appName
    var sortOrder: SortOrder = .ascending
    
    enum ShieldSortOption: String, CaseIterable {
        case appName = "app_name"
        case shieldType = "shield_type"
        case status = "status"
        case expiryTime = "expiry_time"
        case lastUpdated = "last_updated"
        
        var displayName: String {
            switch self {
            case .appName: return "App Name"
            case .shieldType: return "Shield Type"
            case .status: return "Status"
            case .expiryTime: return "Expiry Time"
            case .lastUpdated: return "Last Updated"
            }
        }
    }
    
    enum SortOrder: String, CaseIterable {
        case ascending = "asc"
        case descending = "desc"
        
        var displayName: String {
            switch self {
            case .ascending: return "Ascending"
            case .descending: return "Descending"
            }
        }
    }
    
    /// Check if a shield setting should be shown based on current filters
    func shouldShow(_ setting: SupabaseShieldSetting) -> Bool {
        // Status filter
        if setting.is_shielded && !showShielded { return false }
        if !setting.is_shielded && !showUnshielded { return false }
        
        // Type filter
        if setting.shield_type == "permanent" && !showPermanent { return false }
        if setting.shield_type == "temporary" && !showTemporary { return false }
        
        // Search filter
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            if !setting.app_name.lowercased().contains(searchLower) &&
               !setting.child_name.lowercased().contains(searchLower) {
                return false
            }
        }
        
        return true
    }
}
