# Database Refactor Documentation

## Overview

The database has been refactored to separate shielded and unshielded applications, providing better management of app restrictions and temporary unlocks.

## New Database Structure

### 1. Shielded Applications (`ZapShieldedApplications`)
- **Purpose**: Permanently blocked applications that are added to discouraged apps
- **Storage**: Stored in UserDefaults with key `ZapShieldedApplications`
- **Data Type**: `[UUID: ApplicationProfile]`
- **Behavior**: These apps remain blocked until manually removed from shield

### 2. Unshielded Applications (`ZapUnshieldedApplications`)
- **Purpose**: Temporarily unlocked applications with time limits
- **Storage**: Stored in UserDefaults with key `ZapUnshieldedApplications`
- **Data Type**: `[UUID: UnshieldedApplication]`
- **Behavior**: These apps are automatically re-shielded when their time limit expires

## New Models

### UnshieldedApplication
```swift
struct UnshieldedApplication: Codable, Hashable, Identifiable {
    let id = UUID()
    let applicationToken: ApplicationToken
    let applicationName: String
    let unlockDate: Date
    let durationMinutes: Int
    let expiryDate: Date
    
    // Computed properties for time management
    var isExpired: Bool
    var remainingTime: TimeInterval
    var remainingMinutes: Int
    var remainingSeconds: Int
    var formattedRemainingTime: String
}
```

## Updated Database Methods

### Shielded Applications
- `getShieldedApplications()` - Get all shielded apps
- `addShieldedApplication(_:)` - Add app to shield
- `removeShieldedApplication(_:)` - Remove app from shield
- `saveShieldedApplications(_:)` - Save shielded apps collection

### Unshielded Applications
- `getUnshieldedApplications()` - Get all unshielded apps
- `addUnshieldedApplication(_:)` - Add app to unshielded collection
- `removeUnshieldedApplication(_:)` - Remove app from unshielded collection
- `saveUnshieldedApplications(_:)` - Save unshielded apps collection

### Utility Methods
- `isApplicationShielded(_:)` - Check if app is shielded
- `isApplicationUnshielded(_:)` - Check if app is unshielded
- `getApplicationByName(_:)` - Get app by name with status
- `cleanupExpiredUnshieldedApps()` - Remove expired unshielded apps

## Updated ShieldManager

### New Methods
- `addApplicationToShield(_:)` - Add app to permanent shield
- `removeApplicationFromShield(_:)` - Remove app from permanent shield
- `temporarilyUnlockApplication(_:for:)` - Temporarily unlock app with time limit
- `reapplyShieldToExpiredApp(_:)` - Reapply shield to expired unshielded app
- `getShieldedApplications()` - Get all shielded apps
- `getUnshieldedApplications()` - Get all unshielded apps
- `cleanupExpiredUnshieldedApps()` - Clean up expired apps

### Legacy Support
- `unlockApplication(_:)` - Backward compatible, unlocks for 5 minutes
- `unlockApplication(_:)` - Backward compatible, unlocks by name for 5 minutes

## New Views

### AppStatusView
- Displays both shielded and unshielded applications
- Shows countdown timers for unshielded apps
- Allows manual re-shielding of expired apps
- Provides summary statistics

### AppStatusViewModel
- Manages app status data
- Handles real-time updates
- Provides computed properties for UI
- Manages auto-refresh functionality

## Usage Examples

### Adding an App to Shield
```swift
let appProfile = ApplicationProfile(applicationToken: token, applicationName: "App Name")
ShieldManager.shared.addApplicationToShield(appProfile)
```

### Temporarily Unlocking an App
```swift
let appProfile = ApplicationProfile(applicationToken: token, applicationName: "App Name")
ShieldManager.shared.temporarilyUnlockApplication(appProfile, for: 10) // 10 minutes
```

### Checking App Status
```swift
let database = DataBase()
if let (app, status) = database.getApplicationByName("App Name") {
    switch status {
    case .shielded:
        print("App is permanently blocked")
    case .unshielded:
        print("App is temporarily unlocked")
    }
}
```

## Migration Notes

### Backward Compatibility
- All existing `DataBase` methods continue to work
- `getApplicationProfiles()` returns both shielded and unshielded apps
- `addApplicationProfile(_:)` adds apps as shielded by default
- Existing code will continue to function without changes

### Data Migration
- Existing app profiles will be treated as shielded applications
- No data loss occurs during the refactor
- New structure is automatically applied

## Device Activity Monitoring

### Unshielded App Monitoring
- Each unshielded app gets its own DeviceActivity monitoring
- System automatically re-applies shield when time limit is reached
- Monitoring is handled in `DeviceActivityMonitorExtension`

### Expiry Handling
- Apps are automatically re-shielded when they expire
- Expired apps can be manually re-shielded from the UI
- Cleanup occurs automatically every 30 seconds

## Benefits of New Structure

1. **Clear Separation**: Shielded and unshielded apps are stored separately
2. **Time Management**: Unshielded apps have automatic expiry and re-shielding
3. **Better UX**: Users can see exactly which apps are blocked and for how long
4. **Automatic Cleanup**: Expired unshielded apps are handled automatically
5. **Flexible Management**: Easy to move apps between shielded and unshielded states
6. **Real-time Updates**: UI updates automatically as app status changes

## Future Enhancements

- Custom time limits for different apps
- Scheduled unshielding (e.g., unlock at specific times)
- Parent approval workflow for unshielding requests
- Usage statistics and reporting
- Bulk operations for multiple apps
