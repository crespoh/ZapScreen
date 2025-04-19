import Foundation
import FamilyControls
import ManagedSettings

struct EarningApps {
    let applicationTokens: Set<ApplicationToken>
    let categoryTokens: Set<ActivityCategoryToken>
    
    init(applicationTokens: Set<ApplicationToken>, categoryTokens: Set<ActivityCategoryToken>) {
        self.applicationTokens = applicationTokens
        self.categoryTokens = categoryTokens
    }
}

struct Child: Identifiable, Equatable {
    let id: UUID
    let name: String
    let deviceIdentifier: String
    var appRestrictions: FamilyActivitySelection
    var earningApps: EarningApps
    var timeLimits: [String: TimeInterval]
    var earningRates: [String: TimeInterval]
    var shieldOptions: [TimeInterval]
    
    init(name: String, deviceIdentifier: String) {
        self.id = UUID()
        self.name = name
        self.deviceIdentifier = deviceIdentifier
        self.appRestrictions = FamilyActivitySelection()
        self.earningApps = EarningApps(applicationTokens: [], categoryTokens: [])
        self.timeLimits = [:]
        self.earningRates = [:]
        self.shieldOptions = [600, 1200, 1800] // 10, 20, 30 minutes in seconds
    }
    
    static func == (lhs: Child, rhs: Child) -> Bool {
        lhs.id == rhs.id
    }
} 