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
        print("[DeviceActivityMonitor] Interval ended for activity: \(activity.rawValue)")
        
        let database = DataBase()
        
        // Look for unlock session by DeviceActivity ID
        if let session = database.getUnlockSession(activityId: activity.rawValue) {
            print("[DeviceActivityMonitor] Found unlock session for: \(session.applicationName)")
            
            // Mark session as expired
            database.expireUnlockSession(session.id)
            
            // Re-lock the app using ShieldManager
            let shieldManager = ShieldManager.shared
            shieldManager.endUnlockSession(for: session.applicationToken)
            
            print("[DeviceActivityMonitor] Re-locked app: \(session.applicationName)")
        } else {
            print("[DeviceActivityMonitor] No unlock session found for activity: \(activity.rawValue)")
        }
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        // Handle the event reaching its threshold.
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
    }
}
