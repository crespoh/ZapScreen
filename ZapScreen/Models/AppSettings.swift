import Foundation
import FamilyControls
import ManagedSettings

class AppSettings: ObservableObject {
    @Published var isParentMode: Bool = false
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
    
    func setAppRestrictions() {
        // Set application restrictions
        let applications = selectedApps.applicationTokens.map { Application(token: $0) }
        store.application.blockedApplications = Set(applications)
    }
    
    func setEarningApps() {
        // Set earning apps configuration
        // This will be used by the Device Activity Monitor
    }
    
    func requestAdditionalTime(minutes: TimeInterval, for app: String) {
        // Handle additional time request from child
    }
    
    func approveTimeRequest(minutes: TimeInterval, for app: String) {
        // Approve time request from parent
        if let currentLimit = timeLimits[app] {
            timeLimits[app] = currentLimit + (minutes * 60)
        }
    }
} 