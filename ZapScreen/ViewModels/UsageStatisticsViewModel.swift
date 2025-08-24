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
    @Published var usageRecords: [UsageRecord] = []
    @Published var usageData: [UsageData] = []
    @Published var isLoading: Bool = false
    
    private let database = DataBase()
    
    // Computed properties for the simplified view
    var totalTimeFormatted: String {
        let totalMinutes = usageStatistics.reduce(0) { $0 + $1.totalTimeApprovedMinutes }
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(totalMinutes)m"
        }
    }
    
    var totalRequests: Int {
        usageStatistics.reduce(0) { $0 + $1.totalRequestsApproved }
    }
    
    func loadUsageStatistics(for timeRange: TimeRange) {
        isLoading = true
        
        Task {
            await loadLocalStatistics(for: timeRange)
        }
    }
    
    @MainActor
    private func loadLocalStatistics(for timeRange: TimeRange) async {
        // Convert TimeRange to DateRange for the database
        let dateRange = convertTimeRangeToDateRange(timeRange)
        let statistics = database.getUsageStatistics(for: dateRange)
        
        // Update usage statistics
        usageStatistics = Array(statistics.values).sorted { first, second in
            first.totalTimeApprovedMinutes > second.totalTimeApprovedMinutes
        }
        
        // Extract all usage records and sort by date
        let allRecords = statistics.values.flatMap { $0.usageRecords }
        usageRecords = allRecords.sorted { $0.approvedDate > $1.approvedDate }
        
        // Create chart data
        usageData = createChartData(from: allRecords, for: timeRange)
        
        isLoading = false
    }
    
    private func convertTimeRangeToDateRange(_ timeRange: TimeRange) -> DateRange {
        switch timeRange {
        case .today:
            return .today
        case .thisWeek:
            return .thisWeek
        case .thisMonth:
            return .thisMonth
        case .allTime:
            return .allTime
        }
    }
    
    private func createChartData(from records: [UsageRecord], for timeRange: TimeRange) -> [UsageData] {
        let calendar = Calendar.current
        let now = Date()
        
        // Group records by date and sum minutes
        var dailyUsage: [Date: Int] = [:]
        
        for record in records {
            let dayStart = calendar.startOfDay(for: record.approvedDate)
            dailyUsage[dayStart, default: 0] += record.durationMinutes
        }
        
        // Create UsageData objects for chart
        let sortedDates = dailyUsage.keys.sorted()
        return sortedDates.map { date in
            UsageData(date: date, minutes: dailyUsage[date] ?? 0)
        }
    }
    
    // Legacy methods for backward compatibility
    func loadUsageStatistics() {
        loadUsageStatistics(for: .allTime)
    }
    
    func changeDateRange(_ range: DateRange) {
        // Convert DateRange to TimeRange and reload
        let timeRange = convertDateRangeToTimeRange(range)
        loadUsageStatistics(for: timeRange)
    }
    
    private func convertDateRangeToTimeRange(_ dateRange: DateRange) -> TimeRange {
        switch dateRange {
        case .today:
            return .today
        case .thisWeek:
            return .thisWeek
        case .thisMonth:
            return .thisMonth
        default:
            return .allTime
        }
    }
    
    func changeSortOption(_ option: SortOption) {
        // For the simplified view, we don't need complex sorting
        // Just reload with current time range
        loadUsageStatistics(for: .allTime)
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
    
    // Legacy enum for backward compatibility
    enum SortOption: String, CaseIterable {
        case appName = "App Name"
        case totalRequests = "Total Requests"
        case totalTime = "Total Time"
        case lastUsed = "Last Used"
        case todayUsage = "Today's Usage"
        case weekUsage = "This Week"
        case monthUsage = "This Month"
    }
    
    enum DataSource: String, CaseIterable {
        case local = "Local"
        case remote = "Remote"
    }
}
