import Foundation
import FamilyControls

struct Child: Identifiable, Equatable {
    let id: UUID
    let name: String
    let deviceIdentifier: String
    var appRestrictions: FamilyActivitySelection
    var earningApps: FamilyActivitySelection
    var timeLimits: [String: TimeInterval]
    var earningRates: [String: TimeInterval]
    var shieldOptions: [TimeInterval]
    
    init(name: String, deviceIdentifier: String) {
        self.id = UUID()
        self.name = name
        self.deviceIdentifier = deviceIdentifier
        self.appRestrictions = FamilyActivitySelection()
        self.earningApps = FamilyActivitySelection()
        self.timeLimits = [:]
        self.earningRates = [:]
        self.shieldOptions = [600, 1200, 1800] // 10, 20, 30 minutes in seconds
    }
    
    static func == (lhs: Child, rhs: Child) -> Bool {
        lhs.id == rhs.id
    }
} 