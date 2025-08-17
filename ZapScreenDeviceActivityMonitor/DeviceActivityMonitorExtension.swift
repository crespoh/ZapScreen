//
//  DeviceActivityMonitorExtension.swift
//  ZapScreenDeviceActivityMonitor
//
//  Created by tongteknai on 22/4/25.
//

import DeviceActivity
import Foundation
import ManagedSettings

// Optionally override any of the functions below.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        // Handle the start of the interval.
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        
        // Handle the end of the interval.
        let database = DataBase()
        guard let activityId = UUID(uuidString: activity.rawValue) else { return }
        
        // Check if this is an unshielded application that has expired
        if let unshieldedApp = database.getUnshieldedApplication(id: activityId) {
            // Get the ApplicationToken from the referenced shielded app
            let applicationToken = unshieldedApp.shieldedAppToken
            // Reapply shield to expired app
            let store = ManagedSettingsStore()
            store.shield.applications?.insert(applicationToken)
            
            // Remove from unshielded collection
            database.removeUnshieldedApplication(unshieldedApp)
            
            print("[DeviceActivityMonitor] Reapplied shield to expired app: \(unshieldedApp.applicationName)")
        }
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        // Handle the event reaching its threshold.
        // This is called when the time limit is reached
        let database = DataBase()
        guard let activityId = UUID(uuidString: activity.rawValue) else { return }
        
        // Check if this is an unshielded application that has reached its threshold
        if let unshieldedApp = database.getUnshieldedApplication(id: activityId) {
            // Get the ApplicationToken from the referenced shielded app
            let applicationToken = unshieldedApp.shieldedAppToken
            // Reapply shield to app that has reached its time limit
            let store = ManagedSettingsStore()
            store.shield.applications?.insert(applicationToken)
            
            // Remove from unshielded collection
            database.removeUnshieldedApplication(unshieldedApp)
            
            print("[DeviceActivityMonitor] Reapplied shield to app that reached time limit: \(unshieldedApp.applicationName)")
        }
    }
    
    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        
        // Handle the warning before the interval starts.
    }
    
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        
        // Handle the warning before the interval ends.
    }
    
    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        
        // Handle the warning before the event reaches its threshold.
        // This can be used to show a warning that the app will be re-shielded soon
        let database = DataBase()
        guard let activityId = UUID(uuidString: activity.rawValue) else { return }
        
        if let unshieldedApp = database.getUnshieldedApplication(id: activityId) {
            // Show warning that app will be re-shielded soon
            print("[DeviceActivityMonitor] Warning: App \(unshieldedApp.applicationName) will be re-shielded in 1 minute")
        }
    }
}
