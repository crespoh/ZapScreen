//
//  ShieldConfigurationExtension.swift
//  ShieldConfiguration
//
//  Created by tongteknai on 18/4/25.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

// Override the functions below to customize the shields used in various situations.
// The system provides a default appearance for any methods that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundColor: .blue,
            icon: UIImage(systemName: "lock.shield.fill"),
            title: ShieldConfiguration.Label(text: "Time's Up!", color: .white),
            subtitle: ShieldConfiguration.Label(text: "You've reached your screen time limit", color: .white),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Ask for More Time", color: .white),
            primaryButtonBackgroundColor: .green,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Close App", color: .white)
        )
    }
    
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundColor: .blue,
            icon: UIImage(systemName: "lock.shield.fill"),
            title: ShieldConfiguration.Label(text: "Time's Up!", color: .white),
            subtitle: ShieldConfiguration.Label(text: "You've reached your screen time limit", color: .white),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Ask for More Time", color: .white),
            primaryButtonBackgroundColor: .green,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Close App", color: .white)
        )
    }
    
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundColor: .blue,
            icon: UIImage(systemName: "lock.shield.fill"),
            title: ShieldConfiguration.Label(text: "Time's Up!", color: .white),
            subtitle: ShieldConfiguration.Label(text: "You've reached your screen time limit", color: .white),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Ask for More Time", color: .white),
            primaryButtonBackgroundColor: .green,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Close App", color: .white)
        )
    }
    
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundColor: .blue,
            icon: UIImage(systemName: "lock.shield.fill"),
            title: ShieldConfiguration.Label(text: "Time's Up!", color: .white),
            subtitle: ShieldConfiguration.Label(text: "You've reached your screen time limit", color: .white),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Ask for More Time", color: .white),
            primaryButtonBackgroundColor: .green,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Close App", color: .white)
        )
    }
}
