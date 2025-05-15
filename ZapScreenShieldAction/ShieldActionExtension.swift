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
        switch action {
        case .primaryButtonPressed:
            logger.info("Primary button pressed for application")
            
            struct AppTokenName: Codable {
                let tokenData: Data
                let name: String
            }
            let tokenNameListKey = "ZapAppTokenNameList"
            let userDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
            let tokenKey: String
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: application, requiringSecureCoding: true) {
                tokenKey = data.base64EncodedString()
                logger.info("[ZapScreen] Used archivedData for tokenKey")
            } else {
                tokenKey = String(describing: application)
                logger.info("[ZapScreen] Used String(describing:) for tokenKey: \(tokenKey)")
            }
            var appName: String? = nil
            if let mapping = userDefaults?.dictionary(forKey: tokenNameListKey) as? [String: String] {
                appName = mapping[tokenKey]
                if let appName = appName {
                    logger.info("[ZapScreen] Successfully extracted app name '\(appName)' for tokenKey \(tokenKey) from UserDefaults")
                } else {
                    logger.info("[ZapScreen] No app name found in UserDefaults for tokenKey \(tokenKey)")
                }
            } else {
                logger.error("[ZapScreen] No mapping dictionary found in UserDefaults for key \(tokenNameListKey)")
            }
            // Create application profile with saved name if available
            createApplicationProfile(for: application, withName: appName)
            // Send unlock event to server using the mapped app name
            ZapScreenManager.shared.sendUnlockEvent(bundleIdentifier: appName ?? "")
            
            startMonitoring()
            unlockApp()
            completionHandler(.close)
            
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
    
    func createApplicationProfile(for application: ApplicationToken, withName name: String? = nil) {
        logger.info("Creating application profile")
        self.applicationProfile = ApplicationProfile(
            applicationToken: application,
            applicationName: name ?? "App \(application.hashValue)" // Use provided name or generate one
        )
        let dataBase = DataBase()
        dataBase.addApplicationProfile(self.applicationProfile)
        logger.info("Application profile created with name: \(self.applicationProfile.applicationName)")
    }
        
    // Start a device activity for this particular application
    func startMonitoring() {
        logger.info("Starting device activity monitoring")
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
        }
    }
    
    // remove the shield of this application
    func unlockApp() {
        logger.info("Unlocking application")
        let store = ManagedSettingsStore()
        store.shield.applications?.remove(self.applicationProfile.applicationToken)
        logger.info("Application unlocked")
    }
}
