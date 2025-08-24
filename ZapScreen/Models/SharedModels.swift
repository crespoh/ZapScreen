//
//  SharedModels.swift
//  ZapScreen
//
//  Created by tongteknai on 18/5/25.
//

import Foundation

// MARK: - User Role Enum
enum UserRole: String, CaseIterable, Identifiable {
    case parent = "Parent"
    case child = "Child"
    
    var id: String { rawValue }
    
    static var selectionCases: [UserRole] {
        return [.parent, .child]
    }
}

// MARK: - Time Range Enum
enum TimeRange: String, CaseIterable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case allTime = "All Time"
    
    var displayName: String { rawValue }
}

// MARK: - Usage Data for Charts
struct UsageData: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Int
}
