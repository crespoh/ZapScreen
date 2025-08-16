//
//  ApplicationProfile.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import Foundation
import ManagedSettings

struct ApplicationProfile: Codable, Hashable, Identifiable {
    let id: UUID
    let applicationToken: ApplicationToken
    let applicationName: String
    
    init(applicationToken: ApplicationToken, applicationName: String) {
        self.id = UUID()
        self.applicationToken = applicationToken
        self.applicationName = applicationName
    }
    
    // Custom initializer for creating from existing data
    init(id: UUID, applicationToken: ApplicationToken, applicationName: String) {
        self.id = id
        self.applicationToken = applicationToken
        self.applicationName = applicationName
    }
}
