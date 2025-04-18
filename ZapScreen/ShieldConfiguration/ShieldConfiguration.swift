import ManagedSettings
import SwiftUI

class ShieldConfigurationProvider: ShieldConfigurationProvider {
    override func configuration(for application: Application) -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundEffect: .blur,
            backgroundColor: .blue,
            icon: UIImage(systemName: "lock.shield.fill"),
            title: "Time's Up!",
            subtitle: "You've reached your screen time limit",
            primaryButtonLabel: "Ask for More Time",
            primaryButtonBackgroundColor: .green,
            secondaryButtonLabel: "Close App"
        )
    }
} 