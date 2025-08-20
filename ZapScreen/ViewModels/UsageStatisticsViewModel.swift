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
    
    private let database = DataBase()
    
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
}
