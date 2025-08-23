//
//  ShieldSettingsModels.swift
//  ZapScreen
//
//  Created for Phase 1: Child Shield Settings to Supabase
//

import Foundation
import ManagedSettings

// MARK: - Shield Settings Summary Models

/// Summary of shield settings for a child device
public struct ChildShieldSummary: Codable, Identifiable {
    public let child_device_id: String
    public let device_owner: String // Renamed from child_name to device_owner
    public let total_apps: Int
    public let shielded_apps: Int
    public let unshielded_apps: Int
    public let last_updated: String
    
    public var id: String { child_device_id }
    
    /// Convert last_updated string to Date
    public var lastUpdatedDate: Date? {
        ISO8601DateFormatter().date(from: last_updated)
    }
    
    /// Calculate percentage of shielded apps
    public var shieldedPercentage: Double {
        guard total_apps > 0 else { return 0 }
        return Double(shielded_apps) / Double(total_apps) * 100
    }
}

/// Summary of all children's shield settings for a parent
public struct ParentShieldSummary: Codable {
    public let total_children: Int
    public let total_apps: Int
    public let total_shielded: Int
    public let total_unshielded: Int
    public let children_summaries: [ChildShieldSummary]
    
    /// Calculate overall shielded percentage
    public var overallShieldedPercentage: Double {
        guard total_apps > 0 else { return 0 }
        return Double(total_shielded) / Double(total_apps) * 100
    }
    
    /// Get summary for a specific child
    public func summaryForChild(_ childDeviceId: String) -> ChildShieldSummary? {
        return children_summaries.first { $0.child_device_id == childDeviceId }
    }
}

// MARK: - Shield Settings Change Models

/// Model for tracking shield setting changes
public struct ShieldSettingChange: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let child_device_id: String
    public let device_owner: String // Renamed from child_name to device_owner
    public let app_name: String
    public let bundle_identifier: String
    public let change_type: ShieldChangeType
    public let previous_status: String?
    public let new_status: String
    public let duration_minutes: Int?
    
    public init(timestamp: Date, childDeviceId: String, childName: String, appName: String, bundleIdentifier: String, changeType: ShieldChangeType, previousStatus: String?, newStatus: String, durationMinutes: Int?) {
        self.id = UUID()
        self.timestamp = timestamp
        self.child_device_id = childDeviceId
        self.device_owner = childName
        self.app_name = appName
        self.bundle_identifier = bundleIdentifier
        self.change_type = changeType
        self.previous_status = previousStatus
        self.new_status = newStatus
        self.duration_minutes = durationMinutes
    }
    
    public enum ShieldChangeType: String, Codable, CaseIterable {
        case added = "added"
        case removed = "removed"
        case temporarilyUnlocked = "temporarily_unlocked"
        case reShielded = "re_shielded"
        case expired = "expired"
        
        public var displayName: String {
            switch self {
            case .added: return "Added to Shield"
            case .removed: return "Removed from Shield"
            case .temporarilyUnlocked: return "Temporarily Unlocked"
            case .reShielded: return "Re-shielded"
            case .expired: return "Expired"
            }
        }
        
        public var icon: String {
            switch self {
            case .added: return "shield.fill"
            case .removed: return "shield.slash"
            case .temporarilyUnlocked: return "lock.open"
            case .reShielded: return "shield"
            case .expired: return "clock.badge.exclamationmark"
            }
        }
        
        public var color: String {
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
public struct ShieldSettingsFilter {
    public var showShielded: Bool = true
    public var showUnshielded: Bool = true
    public var showPermanent: Bool = true
    public var showTemporary: Bool = true
    public var searchText: String = ""
    public var sortBy: ShieldSortOption = .appName
    public var sortOrder: SortOrder = .ascending
    
    public enum ShieldSortOption: String, CaseIterable {
        case appName = "app_name"
        case shieldType = "shield_type"
        case status = "status"
        case expiryTime = "expiry_time"
        case lastUpdated = "last_updated"
        
        public var displayName: String {
            switch self {
            case .appName: return "App Name"
            case .shieldType: return "Shield Type"
            case .status: return "Status"
            case .expiryTime: return "Expiry Time"
            case .lastUpdated: return "Last Updated"
            }
        }
    }
    
    public enum SortOrder: String, CaseIterable {
        case ascending = "asc"
        case descending = "desc"
        
        public var displayName: String {
            switch self {
            case .ascending: return "Ascending"
            case .descending: return "Descending"
            }
        }
    }
    
    // Note: shouldShow method removed as it referenced internal SupabaseShieldSetting type
    // This method will be reimplemented in Phase 3 when we create the parent views
}
