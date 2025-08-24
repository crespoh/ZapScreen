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
