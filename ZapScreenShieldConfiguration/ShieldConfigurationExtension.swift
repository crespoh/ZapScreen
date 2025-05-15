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
