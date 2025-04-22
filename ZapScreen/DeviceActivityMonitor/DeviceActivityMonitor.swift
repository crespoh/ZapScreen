import DeviceActivity
import ManagedSettings
import FamilyControls

class ZapScreenDeviceActivityMonitor: DeviceActivityMonitor {
    let store = ManagedSettingsStore()
    let center = AuthorizationCenter.shared
    @MainActor private let settings = AppSettings()
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        Task { @MainActor in
            // Wait for authorization to complete
            while settings.authorizationStatus == .notDetermined {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
            
            if settings.isAuthorized {
                let selection = FamilyActivitySelection()
                store.shield.applications = selection.applicationTokens
                store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
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