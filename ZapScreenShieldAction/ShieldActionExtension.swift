//
//  ShieldActionExtension.swift
//  ZapScreenShieldAction
//
//  Created by tongteknai on 22/4/25.
//

import ManagedSettings
import DeviceActivity
import Foundation

// Override the functions below to customize the shield actions used in various situations.
// The system provides a default response for any functions that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldActionExtension: ShieldActionDelegate {
    
    var applicationProfile: ApplicationProfile!
    
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // Handle the action as needed.
        switch action {
        case .primaryButtonPressed:
            print("create app profile")
            createApplicationProfile(for: application)
            startMonitoring()
            print("Unlock app")
            unlockApp()
            completionHandler(.close)
        case .secondaryButtonPressed:
            completionHandler(.defer)
        @unknown default:
            fatalError()
        }
    }
    
    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // Handle the action as needed.
        completionHandler(.close)
    }
    
    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // Handle the action as needed.
        completionHandler(.close)
    }
    
    func createApplicationProfile(for application: ApplicationToken) {
            applicationProfile = ApplicationProfile(applicationToken: application)
            let dataBase = DataBase()
            dataBase.addApplicationProfile(applicationProfile)
    }
        
    // Start a device activity for this particular application
    func startMonitoring() {
        let unlockTime = 2
        let event: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            DeviceActivityEvent.Name(applicationProfile.id.uuidString) : DeviceActivityEvent(
                applications: Set<ApplicationToken>([applicationProfile.applicationToken]),
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
            try center.startMonitoring(DeviceActivityName(applicationProfile.id.uuidString), during: schedule, events: event)
        } catch {
            print("Error monitoring schedule: \(error)")
        }
    }
    
    // remove the shield of this application
    func unlockApp() {
        let store = ManagedSettingsStore()
        store.shield.applications?.remove(applicationProfile.applicationToken)
    }
}
