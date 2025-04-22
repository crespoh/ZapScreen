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
    
    init(id: UUID = UUID(), applicationToken: ApplicationToken) {
        self.applicationToken = applicationToken
        self.id = id
    }
}
