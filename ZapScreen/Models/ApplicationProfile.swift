//
//  ApplicationProfile.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import Foundation
import ManagedSettings

struct ApplicationProfile: Codable, Hashable, Identifiable {
    var id = UUID()
    let applicationToken: ApplicationToken
    let applicationName: String
    
    init(applicationToken: ApplicationToken, applicationName: String) {
        self.applicationToken = applicationToken
        self.applicationName = applicationName
    }
}
