//
//  ShieldActionExtension.swift
//  ZapScreenShieldAction
//
//  Created by tongteknai on 22/4/25.
//

import ManagedSettings
import DeviceActivity
import Foundation
import os.log

// Override the functions below to customize the shield actions used in various situations.
// The system provides a default response for any functions that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldActionExtension: ShieldActionDelegate {
    
    private let logger = Logger(subsystem: "com.ntt.ZapScreen.ZapScreenShieldAction", category: "ShieldAction")
    var applicationProfile: ApplicationProfile!

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        
        print("ShieldActionExtension: handle called")
        logger.error("ShieldActionExtension: handle called") 
        switch action {
        case .primaryButtonPressed:
            print("[ShieldActionExtension]")

            logger.info("Primary button pressed for application")
            
            var appName = ""
            let db = DataBase()
            let profiles = db.getApplicationProfiles()
            for profile in profiles.values {
                if profile.applicationToken == application {
                    appName = profile.applicationName
                }
            }
            
            logger.info("[ShieldActionExtension] Start sendunlockEvent")
            Task {
                logger.info("[AppName]:\(appName)")
                await SupabaseManager.shared.sendUnlockEvent(bundleIdentifier: appName)
                logger.info("sendUnlockEvent triggered")
                completionHandler(.defer)
            }
            
            
        case .secondaryButtonPressed:
            logger.info("Secondary button pressed for application")
            completionHandler(.defer)
            
        @unknown default:
            logger.error("Unknown action received")
            completionHandler(.close)
        }
    }
    
    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        logger.info("Web domain action received: \(String(describing: action))")
        completionHandler(.close)
    }
    
    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        logger.info("Category action received: \(String(describing: action))")
        completionHandler(.close)
    }
    
//    func createApplicationProfile(for application: ApplicationToken, withName name: String? = nil, withBundleId bundleid: String? = nil) {
//        logger.info("Creating application profile")
//        self.applicationProfile = ApplicationProfile(
//            applicationToken: application,
//            applicationName: name ?? "App \(application.hashValue)",
//            applicationBundleId: bundleid ?? ""
//        )
//        let dataBase = DataBase()
//        dataBase.addApplicationProfile(self.applicationProfile)
//        logger.info("Application profile created with name: \(self.applicationProfile.applicationName)")
//    }
        
    // Start a device activity for this particular application
    func startMonitoring() {
        logger.info("Starting device activity monitoring")
        
        // Stop any existing monitoring for this app first
        stopMonitoring()
        
        let unlockTime = 2
        let event: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            (DeviceActivityEvent.Name(self.applicationProfile.id.uuidString) as DeviceActivityEvent.Name): DeviceActivityEvent(
                applications: Set<ApplicationToken>([self.applicationProfile.applicationToken]),
                threshold: DateComponents(minute: unlockTime)
            )
        ]
        
        let intervalEnd = Calendar.current.dateComponents(
            [.hour, .minute, .second],
            from: Calendar.current.date(byAdding: .minute, value: unlockTime, to: Date.now) ?? Date.now
        )
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: intervalEnd,
            repeats: false
        )
         
        let center = DeviceActivityCenter()
        do {
            try center.startMonitoring(DeviceActivityName(self.applicationProfile.id.uuidString), during: schedule, events: event)
            logger.info("Successfully started monitoring")
        } catch {
            logger.error("Error monitoring schedule: \(error.localizedDescription)")
            print("Error monitoring schedule: \(error)")
            
            // If it's an excessive activities error, try to stop all monitoring and retry
            if error.localizedDescription.contains("excessiveActivities") {
                logger.info("Attempting to stop all monitoring and retry...")
                stopAllMonitoring()
                
                // Wait a moment and retry
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    do {
                        try center.startMonitoring(DeviceActivityName(self.applicationProfile.id.uuidString), during: schedule, events: event)
                        self.logger.info("Successfully started monitoring after cleanup")
                    } catch {
                        self.logger.error("Failed to start monitoring after cleanup: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func stopMonitoring() {
        let center = DeviceActivityCenter()
        center.stopMonitoring([DeviceActivityName(self.applicationProfile.id.uuidString)])
        logger.info("Stopped monitoring for: \(self.applicationProfile.id.uuidString)")
    }
    
    func stopAllMonitoring() {
        let center = DeviceActivityCenter()
        // Stop all active monitoring sessions
        center.stopMonitoring()
        logger.info("Stopped all monitoring sessions")
    }
    
    // remove the shield of this application
    func unlockApp() {
        logger.info("Unlocking application")
        let store = ManagedSettingsStore()
        store.shield.applications?.remove(self.applicationProfile.applicationToken)
        logger.info("Application unlocked")
    }
}
