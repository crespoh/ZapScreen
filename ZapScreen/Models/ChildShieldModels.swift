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
}
