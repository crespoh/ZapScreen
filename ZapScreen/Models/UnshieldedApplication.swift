//
//  UnshieldedApplication.swift
//  ZapScreen
//
//  Created by tongteknai on 22/4/25.
//

import Foundation
import ManagedSettings

struct UnshieldedApplication: Codable, Hashable, Identifiable {
    var id = UUID()
    let shieldedAppToken: ApplicationToken
    let applicationName: String
    let unlockDate: Date
    let durationMinutes: Int
    let expiryDate: Date
    
    init(shieldedAppToken: ApplicationToken, applicationName: String, durationMinutes: Int) {
        self.shieldedAppToken = shieldedAppToken
        self.applicationName = applicationName
        self.durationMinutes = durationMinutes
        self.unlockDate = Date()
        self.expiryDate = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: Date()) ?? Date()
    }
    
    init(shieldedAppToken: ApplicationToken, applicationName: String, unlockDate: Date, durationMinutes: Int, expiryDate: Date) {
        self.shieldedAppToken = shieldedAppToken
        self.applicationName = applicationName
        self.unlockDate = unlockDate
        self.durationMinutes = durationMinutes
        self.expiryDate = expiryDate
    }
    
    // MARK: - Computed Properties
    
    var isExpired: Bool {
        return Date() >= expiryDate
    }
    
    var remainingTime: TimeInterval {
        return max(0, expiryDate.timeIntervalSince(Date()))
    }
    
    var remainingMinutes: Int {
        return max(0, Int(remainingTime / 60))
    }
    
    var remainingSeconds: Int {
        return max(0, Int(remainingTime.truncatingRemainder(dividingBy: 60)))
    }
    
    var formattedRemainingTime: String {
        let minutes = remainingMinutes
        let seconds = remainingSeconds
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

