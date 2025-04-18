import DeviceActivity
import ManagedSettings
import FamilyControls

class ZapScreenDeviceActivityMonitor: DeviceActivityMonitor {
    let store = ManagedSettingsStore()
    let center = AuthorizationCenter.shared
    let selection = FamilyActivitySelection()
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        // Set up the application restrictions
        let applications = selection.applicationTokens.map { Application(token: $0) }
        store.application.blockedApplications = Set(applications)
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        
        // Remove the restrictions when the interval ends
        store.application.blockedApplications = Set()
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