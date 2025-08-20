//
//  UsageStatisticsViewModel.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import Foundation
import SwiftUI
import ManagedSettings

class UsageStatisticsViewModel: ObservableObject {
    @Published var usageStatistics: [UsageStatistics] = []
    @Published var selectedDateRange: DateRange = .allTime
    @Published var sortOption: SortOption = .appName
    @Published var isLoading: Bool = false
    @Published var dataSource: DataSource = .local // New: local vs remote
    
    private let database = DataBase()
    
    enum DataSource: String, CaseIterable {
        case local = "Local"
        case remote = "Remote"
    }
    
    enum SortOption: String, CaseIterable {
        case appName = "App Name"
        case totalRequests = "Total Requests"
        case totalTime = "Total Time"
        case lastUsed = "Last Used"
        case todayUsage = "Today's Usage"
        case weekUsage = "This Week"
        case monthUsage = "This Month"
    }
    
    func loadUsageStatistics() {
        isLoading = true
        
        Task {
            switch dataSource {
            case .local:
                await loadLocalStatistics()
            case .remote:
                await loadRemoteStatistics()
            }
        }
    }
    
    @MainActor
    private func loadLocalStatistics() async {
        let statistics = database.getUsageStatistics(for: selectedDateRange)
        usageStatistics = Array(statistics.values).sorted { first, second in
            switch sortOption {
            case .appName:
                return first.appName < second.appName
            case .totalRequests:
                return first.totalRequestsApproved > second.totalRequestsApproved
            case .totalTime:
                return first.totalTimeApprovedMinutes > second.totalTimeApprovedMinutes
            case .lastUsed:
                return (first.lastApprovedDate ?? Date.distantPast) > (second.lastApprovedDate ?? Date.distantPast)
            case .todayUsage:
                return first.todayUsage.minutes > second.todayUsage.minutes
            case .weekUsage:
                return first.thisWeekUsage.minutes > second.thisWeekUsage.minutes
            case .monthUsage:
                return first.thisMonthUsage.minutes > second.thisMonthUsage.minutes
            }
        }
        isLoading = false
    }
    
    @MainActor
    private func loadRemoteStatistics() async {
        // For now, skip remote loading until we have proper ApplicationToken handling
        // This will be implemented in future phases
        print("[UsageStatisticsViewModel] Remote loading not yet implemented - falling back to local data")
        await loadLocalStatistics()
    }
    
    func changeDateRange(_ range: DateRange) {
        selectedDateRange = range
        loadUsageStatistics()
    }
    
    func changeSortOption(_ option: SortOption) {
        sortOption = option
        loadUsageStatistics()
    }
    
    // Summary statistics for the selected date range
    var summaryStatistics: (totalApps: Int, totalRequests: Int, totalMinutes: Int) {
        let totalApps = usageStatistics.count
        let totalRequests = usageStatistics.reduce(0) { $0 + $1.totalRequestsApproved }
        let totalMinutes = usageStatistics.reduce(0) { $0 + $1.totalTimeApprovedMinutes }
        return (totalApps, totalRequests, totalMinutes)
    }
    
    // Export usage data as CSV
    func exportUsageData() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        var csv = "App Name,Total Requests,Total Minutes,Last Approved,Today (min),This Week (min),This Month (min)\n"
        
        for stat in usageStatistics {
            let lastDate = stat.lastApprovedDate.map { dateFormatter.string(from: $0) } ?? "Never"
            let today = stat.todayUsage.minutes
            let week = stat.thisWeekUsage.minutes
            let month = stat.thisMonthUsage.minutes
            
            csv += "\"\(stat.appName)\",\(stat.totalRequestsApproved),\(stat.totalTimeApprovedMinutes),\"\(lastDate)\",\(today),\(week),\(month)\n"
        }
        
        return csv
    }
    
    // Get formatted summary text
    var summaryText: String {
        let stats = summaryStatistics
        return "\(stats.totalApps) apps, \(stats.totalRequests) requests, \(stats.totalMinutes) minutes"
    }
}
