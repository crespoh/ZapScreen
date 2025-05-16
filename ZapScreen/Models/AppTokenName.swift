//
//  AppTokenName.swift
//  ZapScreen
//
//  Created by tongteknai on 16/5/25.
//

import Foundation
import SwiftData
import ManagedSettings

@Model
class AppTokenName {
    var name: String
    var token: ApplicationToken

    init(name: String, token: ApplicationToken) {
        self.name = name
        self.token = token
    }
}
