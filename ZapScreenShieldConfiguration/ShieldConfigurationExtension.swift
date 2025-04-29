//
//  ShieldConfigurationExtension.swift
//  ZapScreenShieldConfiguration
//
//  Created by tongteknai on 23/4/25.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit
import os.log

// Override the functions below to customize the shields used in various situations.
// The system provides a default appearance for any methods that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    // Use a more specific subsystem and category
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.ntt.ZapScreen", category: "ShieldConfiguration")
    
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // Get the application name and token
        let appName = application.localizedDisplayName ?? "Unknown App"
        guard let appToken = application.token else {
            // Use fault level for critical errors
            logger.fault("🔴 Failed to get application token")
            return ShieldConfiguration(
                backgroundColor: .systemCyan,
                title: ShieldConfiguration.Label(text: "Error: Could not get app token", color: .label),
                subtitle: ShieldConfiguration.Label(text: "Please try again", color: .systemBrown),
                primaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: .label),
                primaryButtonBackgroundColor: .systemRed,
                secondaryButtonLabel: ShieldConfiguration.Label(text: "Cancel", color: .label)
            )
        }
        
        // Use debug level for detailed information
        logger.debug("🟡 Starting UserDefaults update for app: \(appName)")
        
        // Try to save to UserDefaults
        if let defaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") {
            logger.debug("🟡 Attempting to save values to UserDefaults")
            defaults.set(appName, forKey: "lastBlockedAppName")
            defaults.set(String(describing: appToken), forKey: "lastBlockedAppToken")
            defaults.synchronize()
            
            // Verify the values were saved
            let savedName = defaults.string(forKey: "lastBlockedAppName")
            let savedToken = defaults.string(forKey: "lastBlockedAppToken")
            
            if savedName == appName && savedToken == String(describing: appToken) {
                logger.info("🟢 Successfully saved and verified UserDefaults values")
                logger.info("   App Name: \(appName)")
                logger.info("   App Token: \(String(describing: appToken))")
            } else {
                logger.error("🔴 Failed to verify UserDefaults update")
                logger.error("   Expected Name: \(appName)")
                logger.error("   Expected Token: \(String(describing: appToken))")
                logger.error("   Got Name: \(savedName ?? "nil")")
                logger.error("   Got Token: \(savedToken ?? "nil")")
            }
        } else {
            logger.error("🔴 Failed to access UserDefaults with suite name: group.com.ntt.ZapScreen.data")
        }
        
        // Customize the shield as needed for applications.
        return ShieldConfiguration(
            backgroundColor: .systemCyan,
            title: ShieldConfiguration.Label(text: "Do you really need to use this app \(appName)?", color: .label),
            subtitle: ShieldConfiguration.Label(text: "Like are you sure?", color: .systemBrown),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Unlock", color: .label),
            primaryButtonBackgroundColor: .systemGreen,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Don't unlock.", color: .label)
        )
    }
    
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        // Customize the shield as needed for applications shielded because of their category.
        ShieldConfiguration()
    }
    
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        // Customize the shield as needed for web domains.
        ShieldConfiguration()
    }
    
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        // Customize the shield as needed for web domains shielded because of their category.
        ShieldConfiguration()
    }
}
