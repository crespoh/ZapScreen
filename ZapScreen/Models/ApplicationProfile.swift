//
//  ApplicationProfile.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import Foundation
import ManagedSettings

struct ApplicationProfile: Codable, Hashable {
    let id: UUID
    let applicationToken: ApplicationToken
    let applicationName: String
    
    init(id: UUID = UUID(), applicationToken: ApplicationToken, applicationName: String) {
        self.applicationToken = applicationToken
        self.id = id
        self.applicationName = applicationName
    }
}
