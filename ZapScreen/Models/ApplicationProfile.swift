//
//  ApplicationProfile.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import Foundation
import ManagedSettings

struct ApplicationProfile: Codable, Hashable, Identifiable {
    let id = UUID()
    let applicationToken: ApplicationToken
    let applicationName: String
    let applicationBundleId: String
    let applicationLocalizedAppName: String
    // Removed 'application' property because it is not Codable
    
    init(applicationToken: ApplicationToken, applicationName: String, applicationBundleId: String, applicationLocalizedAppName: String) {
        self.applicationToken = applicationToken
        self.applicationName = applicationName
        self.applicationBundleId = applicationBundleId
        self.applicationLocalizedAppName = applicationLocalizedAppName
    }
}
