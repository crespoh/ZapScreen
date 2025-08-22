//
//  ChildShieldModels.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import Foundation

// MARK: - Child Shield Summary Model

struct ChildShieldSettingsSummary: Identifiable {
    let id = UUID()
    let deviceId: String
    let childName: String
    let totalShieldedApps: Int
    let unshieldedApps: [SupabaseShieldSetting]
    let nextExpiryTime: Date?
    
    var hasUnshieldedApps: Bool {
        !unshieldedApps.isEmpty
    }
    
    var totalApps: Int {
        totalShieldedApps + unshieldedApps.count
    }
    
    // MARK: - Enhanced Statistics
    
    var shieldedPercentage: Double {
        guard totalApps > 0 else { return 0 }
        return Double(totalShieldedApps) / Double(totalApps) * 100
    }
    
    var unshieldedPercentage: Double {
        guard totalApps > 0 else { return 0 }
        return Double(unshieldedApps.count) / Double(totalApps) * 100
    }
    
    var hasExpiringUnlocks: Bool {
        guard let nextExpiry = nextExpiryTime else { return false }
        return nextExpiry > Date()
    }
    
    var timeUntilNextExpiry: TimeInterval? {
        guard let nextExpiry = nextExpiryTime else { return nil }
        return nextExpiry.timeIntervalSinceNow
    }
    
    var formattedTimeUntilExpiry: String? {
        guard let timeInterval = timeUntilNextExpiry, timeInterval > 0 else { return nil }
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Search Helper Methods
    
    func hasShieldedApps(_ searchText: String) -> Bool {
        // This would need to be implemented if we had access to the actual shielded app names
        // For now, return false to avoid compilation errors
        return false
    }
    
    func hasUnshieldedApps(_ searchText: String) -> Bool {
        return unshieldedApps.contains { app in
            app.app_name.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Filter and Sort Enums

enum ShieldFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case shieldedOnly = "Shielded Only"
    case unshieldedOnly = "Unshielded Only"
    case mixed = "Mixed Status"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .shieldedOnly: return "shield.fill"
        case .unshieldedOnly: return "lock.open"
        case .mixed: return "shield.lefthalf.filled"
        }
    }
}

enum ShieldSort: String, CaseIterable, Identifiable {
    case nameAsc = "Name (A-Z)"
    case nameDesc = "Name (Z-A)"
    case appCountAsc = "App Count (Low-High)"
    case appCountDesc = "App Count (High-Low)"
    case shieldedCountAsc = "Shielded Apps (Low-High)"
    case shieldedCountDesc = "Shielded Apps (High-Low)"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .nameAsc: return "textformat.abc"
        case .nameDesc: return "textformat.abc"
        case .appCountAsc: return "number.circle"
        case .appCountDesc: return "number.circle"
        case .shieldedCountAsc: return "shield"
        case .shieldedCountDesc: return "shield.fill"
        }
    }
}
