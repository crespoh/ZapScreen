//
//  ShieldExportModels.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import Foundation

// MARK: - Export Data Models

struct ShieldExportData {
    let exportDate: Date
    let familyName: String
    let totalChildren: Int
    let totalApps: Int
    let totalShieldedApps: Int
    let totalUnshieldedApps: Int
    let overallShieldedPercentage: Double
    let childrenData: [ChildShieldExportData]
    
    var formattedExportDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: exportDate)
    }
}

struct ChildShieldExportData {
    let childName: String
    let deviceId: String
    let totalApps: Int
    let shieldedApps: [AppShieldExportData]
    let unshieldedApps: [AppShieldExportData]
    let shieldedPercentage: Double
    let lastUpdated: Date
    
    var formattedLastUpdated: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastUpdated)
    }
}

struct AppShieldExportData {
    let appName: String
    let bundleIdentifier: String
    let isShielded: Bool
    let shieldType: String
    let unlockExpiry: Date?
    let lastUpdated: Date
    
    var status: String {
        if isShielded {
            return "Shielded (\(shieldType))"
        } else {
            if let expiry = unlockExpiry {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                return "Unshielded (Expires: \(formatter.string(from: expiry)))"
            } else {
                return "Unshielded (No expiry)"
            }
        }
    }
    
    var formattedLastUpdated: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: lastUpdated)
    }
}

// MARK: - Export Format Options

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case pdf = "PDF"
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .pdf: return "pdf"
        }
    }
    
    var mimeType: String {
        switch self {
        case .csv: return "text/csv"
        case .pdf: return "application/pdf"
        }
    }
    
    var icon: String {
        switch self {
        case .csv: return "tablecells"
        case .pdf: return "doc.text"
        }
    }
}

// MARK: - Export Filter Options

struct ExportFilter {
    var dateRange: ShieldExportDateRange = .allTime
    var includeShielded: Bool = true
    var includeUnshielded: Bool = true
    var selectedChildren: Set<String> = [] // Empty means all children
    
    var hasActiveFilters: Bool {
        dateRange != .allTime || !includeShielded || !includeUnshielded || !selectedChildren.isEmpty
    }
}

enum ShieldExportDateRange: String, CaseIterable, Identifiable {
    case allTime = "All Time"
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case lastWeek = "Last Week"
    case lastMonth = "Last Month"
    case custom = "Custom Range"
    
    var id: String { rawValue }
    
    var dateInterval: DateInterval? {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .allTime:
            return nil
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return DateInterval(start: startOfDay, end: endOfDay)
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return DateInterval(start: startOfWeek, end: now)
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return DateInterval(start: startOfMonth, end: now)
        case .lastWeek:
            let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            let endOfLastWeek = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            return DateInterval(start: startOfLastWeek, end: endOfLastWeek)
        case .lastMonth:
            let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let endOfLastMonth = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            return DateInterval(start: startOfLastMonth, end: endOfLastMonth)
        case .custom:
            return nil // Will be set separately
        }
    }
}
