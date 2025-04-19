import DeviceActivity
import ManagedSettings
import FamilyControls

class ZapScreenDeviceActivityMonitor: DeviceActivityMonitor {
    let store = ManagedSettingsStore()
    let center = AuthorizationCenter.shared
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        Task {
            do {
                try await center.requestAuthorization(for: .individual)
                let selection = FamilyActivitySelection()
                store.shield.applications = selection.applicationTokens
                store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
            } catch {
                print("Error setting up shield: \(error)")
            }
        }
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store.shield.applications = []
        store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific([])
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        // Handle when usage threshold is reached
        if event.rawValue == "encouraged" {
            // Remove restrictions when child has used earning apps enough
            store.application.blockedApplications = Set()
        }
    }
} 