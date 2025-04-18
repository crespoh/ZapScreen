import Foundation
import FamilyControls
import ManagedSettings

class AppSettings: ObservableObject {
    @Published var isParentMode: Bool = false
    @Published var children: [Child] = []
    @Published var selectedChildId: UUID?
    
    var selectedChild: Child? {
        children.first { $0.id == selectedChildId }
    }
    
    @Published var selectedApps: FamilyActivitySelection = FamilyActivitySelection()
    @Published var earningApps: FamilyActivitySelection = FamilyActivitySelection()
    @Published var timeLimits: [String: TimeInterval] = [:] // App bundle ID to time limit
    @Published var earningRates: [String: TimeInterval] = [:] // App bundle ID to earning rate (minutes per usage)
    @Published var shieldOptions: [TimeInterval] = [600, 1200, 1800] // 10, 20, 30 minutes in seconds
    
    let store = ManagedSettingsStore()
    let center = AuthorizationCenter.shared
    
    init() {
        // Check if device is a child device
        Task {
            await checkDeviceType()
        }
    }
    
    private func checkDeviceType() async {
        do {
            // Try to request authorization for child mode
            try await center.requestAuthorization(for: .individual)
            // If successful, this is a child device
            await MainActor.run {
                isParentMode = false
            }
        } catch {
            // If authorization fails, this is likely a parent device
            // because only child devices can be authorized
            await MainActor.run {
                isParentMode = true
            }
        }
    }
    
    func addChild(name: String, deviceIdentifier: String) {
        let child = Child(name: name, deviceIdentifier: deviceIdentifier)
        children.append(child)
        if selectedChildId == nil {
            selectedChildId = child.id
        }
    }
    
    func setAppRestrictions() {
        guard let child = selectedChild else { return }
        let store = ManagedSettingsStore(named: .init(child.deviceIdentifier))
        
        // Clear existing restrictions
        store.clearAllSettings()
        
        // Set new restrictions
        if !child.appRestrictions.applicationTokens.isEmpty {
            store.shield.applications = child.appRestrictions.applicationTokens
            store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(child.appRestrictions.categoryTokens)
        }
    }
    
    func setEarningApps() {
        guard let child = selectedChild else { return }
        // Set earning apps configuration
        // This will be used by the Device Activity Monitor
    }
    
    func requestAdditionalTime(minutes: TimeInterval, for app: String) {
        // Handle additional time request from child
    }
    
    func approveTimeRequest(minutes: TimeInterval, for app: String) {
        guard let child = selectedChild,
              let currentLimit = child.timeLimits[app] else { return }
        
        // Approve time request from parent
        var updatedChild = child
        updatedChild.timeLimits[app] = currentLimit + (minutes * 60)
        if let index = children.firstIndex(where: { $0.id == child.id }) {
            children[index] = updatedChild
        }
    }
} 