//
//  DataBase.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import Foundation
import ManagedSettings

// MARK: - Usage Statistics Models

struct UsageRecord: Codable, Identifiable {
    let id = UUID()
    let appName: String
    let applicationToken: ApplicationToken
    let approvedDate: Date
    let durationMinutes: Int
    let requestId: String
    
    init(appName: String, applicationToken: ApplicationToken, durationMinutes: Int, requestId: String? = nil) {
        self.appName = appName
        self.applicationToken = applicationToken
        self.approvedDate = Date()
        self.durationMinutes = durationMinutes
        self.requestId = requestId ?? UUID().uuidString
    }
}

struct UsageStatistics: Codable, Identifiable {
    let id = UUID()
    let appName: String
    let applicationToken: ApplicationToken
    var totalRequestsApproved: Int
    var totalTimeApprovedMinutes: Int
    var lastApprovedDate: Date?
    var usageRecords: [UsageRecord]
    
    init(appName: String, applicationToken: ApplicationToken) {
        self.appName = appName
        self.applicationToken = applicationToken
        self.totalRequestsApproved = 0
        self.totalTimeApprovedMinutes = 0
        self.lastApprovedDate = nil
        self.usageRecords = []
    }
    
    // Computed properties for date-based filtering
    var todayUsage: (requests: Int, minutes: Int) {
        let today = Calendar.current.startOfDay(for: Date())
        let todayRecords = usageRecords.filter { 
            Calendar.current.isDate($0.approvedDate, inSameDayAs: today)
        }
        return (
            requests: todayRecords.count,
            minutes: todayRecords.reduce(0) { $0 + $1.durationMinutes }
        )
    }
    
    var thisWeekUsage: (requests: Int, minutes: Int) {
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekRecords = usageRecords.filter { $0.approvedDate >= weekStart }
        return (
            requests: weekRecords.count,
            minutes: weekRecords.reduce(0) { $0 + $1.durationMinutes }
        )
    }
    
    var thisMonthUsage: (requests: Int, minutes: Int) {
        let monthStart = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        let monthRecords = usageRecords.filter { $0.approvedDate >= monthStart }
        return (
            requests: monthRecords.count,
            minutes: monthRecords.reduce(0) { $0 + $1.durationMinutes }
        )
    }
}

// Date range enum
enum DateRange: Equatable {
    case today
    case yesterday
    case thisWeek
    case lastWeek
    case thisMonth
    case lastMonth
    case custom(start: Date, end: Date)
    case allTime
    
    func contains(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            return calendar.isDate(date, inSameDayAs: now)
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            return calendar.isDate(date, inSameDayAs: yesterday)
        case .thisWeek:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return date >= weekStart
        case .lastWeek:
            let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            let lastWeekEnd = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            return date >= lastWeekStart && date <= lastWeekEnd
        case .thisMonth:
            let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return date >= monthStart
        case .lastMonth:
            let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let lastMonthEnd = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            return date >= lastMonthStart && date <= lastMonthEnd
        case .custom(let start, let end):
            return date >= start && date <= end
        case .allTime:
            return true
        }
    }
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "This Week"
        case .lastWeek: return "Last Week"
        case .thisMonth: return "This Month"
        case .lastMonth: return "Last Month"
        case .custom: return "Custom Range"
        case .allTime: return "All Time"
        }
    }
    
    // Manual Equatable implementation for cases with associated values
    static func == (lhs: DateRange, rhs: DateRange) -> Bool {
        switch (lhs, rhs) {
        case (.today, .today),
             (.yesterday, .yesterday),
             (.thisWeek, .thisWeek),
             (.lastWeek, .lastWeek),
             (.thisMonth, .thisMonth),
             (.lastMonth, .lastMonth),
             (.allTime, .allTime):
            return true
        case (.custom(let lhsStart, let lhsEnd), .custom(let rhsStart, let rhsEnd)):
            return lhsStart == rhsStart && lhsEnd == rhsEnd
        default:
            return false
        }
    }
}

// MARK: - Supabase Models

struct SupabaseUsageStatistics: Codable, Identifiable {
    let id: String
    let user_account_id: String
    let child_device_id: String
    let child_device_name: String
    let app_name: String
    let bundle_identifier: String
    let total_requests_approved: Int
    let total_time_approved_minutes: Int
    let last_approved_date: String
    let created_at: String
    let updated_at: String
    
    // Computed properties for date conversion
    var lastApprovedDate: Date? {
        ISO8601DateFormatter().date(from: last_approved_date)
    }
}

struct SupabaseUsageRecord: Codable, Identifiable {
    let id: String
    let user_account_id: String
    let child_device_id: String
    let child_device_name: String
    let app_name: String
    let bundle_identifier: String
    let approved_date: String
    let duration_minutes: Int
    let request_id: String
    let created_at: String
    
    var approvedDate: Date? {
        ISO8601DateFormatter().date(from: approved_date)
    }
}

struct SupabaseUsageStatisticsInsert: Encodable {
    let user_account_id: String
    let child_device_id: String
    let child_device_name: String
    let app_name: String
    let bundle_identifier: String
    let total_requests_approved: Int
    let total_time_approved_minutes: Int
    let last_approved_date: String
}

struct SupabaseUsageRecordInsert: Encodable {
    let user_account_id: String
    let child_device_id: String
    let child_device_name: String
    let app_name: String
    let bundle_identifier: String
    let approved_date: String
    let duration_minutes: Int
    let request_id: String
}

struct DataBase {
    private let defaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
    private let shieldedAppsKey = "ZapShieldedApplications"
    private let unshieldedAppsKey = "ZapUnshieldedApplications"
    private let usageStatisticsKey = "ZapUsageStatistics"
    
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
        for (_, unshieldedApp) in unshieldedApps {
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
    
    // MARK: - Usage Statistics
    
    func getUsageStatistics() -> [String: UsageStatistics] {
        guard let data = defaults?.data(forKey: usageStatisticsKey) else { return [String: UsageStatistics]() }
        guard let decoded = try? JSONDecoder().decode([String: UsageStatistics].self, from: data) else { return [String: UsageStatistics]() }
        return decoded
    }
    
    func saveUsageStatistics(_ statistics: [String: UsageStatistics]) {
        guard let encoded = try? JSONEncoder().encode(statistics) else { return }
        defaults?.set(encoded, forKey: usageStatisticsKey)
    }
    
    func updateUsageStatistics(for appName: String, durationMinutes: Int, requestId: String? = nil) {
        var statistics = getUsageStatistics()
        
        if statistics[appName] == nil {
            // Create new entry if doesn't exist
            // We need to get the ApplicationToken from shielded apps
            if let (appProfile, _) = getApplicationByName(appName) {
                statistics[appName] = UsageStatistics(
                    appName: appName,
                    applicationToken: appProfile.applicationToken
                )
            }
        }
        
        // Create usage record
        if let appProfile = statistics[appName]?.applicationToken {
            let record = UsageRecord(
                appName: appName,
                applicationToken: appProfile,
                durationMinutes: durationMinutes,
                requestId: requestId
            )
            
            // Update statistics
            statistics[appName]?.usageRecords.append(record)
            statistics[appName]?.totalRequestsApproved += 1
            statistics[appName]?.totalTimeApprovedMinutes += durationMinutes
            statistics[appName]?.lastApprovedDate = Date()
        }
        
        saveUsageStatistics(statistics)
    }
    
    // New methods for date-based filtering
    func getUsageStatistics(for dateRange: DateRange) -> [String: UsageStatistics] {
        let allStats = getUsageStatistics()
        var filteredStats: [String: UsageStatistics] = [:]
        
        for (appName, stat) in allStats {
            let filteredRecords = stat.usageRecords.filter { record in
                dateRange.contains(record.approvedDate)
            }
            
            if !filteredRecords.isEmpty {
                var filteredStat = stat
                filteredStat.usageRecords = filteredRecords
                filteredStat.totalRequestsApproved = filteredRecords.count
                filteredStat.totalTimeApprovedMinutes = filteredRecords.reduce(0) { $0 + $1.durationMinutes }
                filteredStats[appName] = filteredStat
            }
        }
        
        return filteredStats
    }
}

// MARK: - Supporting Types

enum AppStatus {
    case shielded
    case unshielded
}
