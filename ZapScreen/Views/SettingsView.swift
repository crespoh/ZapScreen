//
//  SettingsView.swift
//  ZapScreen
//
//  Created by tongteknai on 18/5/25.
//

import SwiftUI
import ManagedSettings
import ManagedSettingsUI
import FamilyControls

struct SettingsView: View {
    @EnvironmentObject var appIconStore: AppIconStore
    @AppStorage("debugModeEnabled", store: UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")) private var debugModeEnabled = false
    
    var body: some View {
        NavigationView {
            List {
                // Debug Mode Toggle
                Section("Debug Settings") {
                    Toggle("Enable Debug Mode", isOn: $debugModeEnabled)
                        .onChange(of: debugModeEnabled) { newValue in
                            print("[SettingsView] Debug mode \(newValue ? "enabled" : "disabled")")
                        }
                    
                    if debugModeEnabled {
                        Text("Debug features are now available in the main tabs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Debug features are hidden from the main interface")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Debug Features (only shown when debug mode is enabled)
                if debugModeEnabled {
                    Section("Debug Features") {
                        NavigationLink("App Icons Database", destination: AppIconListView())
                            .foregroundColor(.blue)
                        
                        NavigationLink("Group UserDefaults", destination: GroupUserDefaultsView())
                            .foregroundColor(.blue)
                        
                        NavigationLink("Device Activity Report", destination: DeviceActivityView())
                            .foregroundColor(.blue)
                        
                        NavigationLink("Device List", destination: DeviceListView())
                            .foregroundColor(.blue)
                        
                        Button("Reset Authorization") {
                            resetAuthorization()
                        }
                        .foregroundColor(.red)
                        
                        Button("Check Authorization Status") {
                            checkAuthorizationStatus()
                        }
                        .foregroundColor(.blue)
                        
                        Button("Check Shield Status") {
                            checkShieldStatus()
                        }
                        .foregroundColor(.orange)
                        
                        Button("Force Apply Shields") {
                            forceApplyShields()
                        }
                        .foregroundColor(.purple)
                    }
                    
                    Section("Debug Information") {
                        HStack {
                            Text("App Icons Count")
                            Spacer()
                            Text("\(appIconStore.apps.count)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("System Region")
                            Spacer()
                            Text(Locale.current.regionCode ?? "Unknown")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Debug Mode")
                            Spacer()
                            Text(debugModeEnabled ? "Enabled" : "Disabled")
                                .foregroundColor(debugModeEnabled ? .green : .red)
                        }
                    }
                }
                
                        // Device Management
                Section("Device Management") {
                    NavigationLink("Scan Child Device QR Code", destination: QRCodeScannerView())
                        .foregroundColor(.green)
                }
                
                // Notifications
                Section("Notifications") {
                    HStack {
                        Image(systemName: "bell.circle")
                            .foregroundColor(.purple)
                        Text("Smart Notifications")
                        Spacer()
                        if ShieldNotificationService.shared.isNotificationsEnabled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    
                    NavigationLink("Notification Preferences") {
                        NotificationPreferencesView()
                    }
                    
                    Button("Request Permissions") {
                        Task {
                            await ShieldNotificationService.shared.requestNotificationPermissions()
                        }
                    }
                    .foregroundColor(.blue)
                    .disabled(ShieldNotificationService.shared.isNotificationsEnabled)
                }
                
                // Performance
                Section("Performance") {
                    HStack {
                        Image(systemName: "speedometer")
                            .foregroundColor(.orange)
                        Text("Cache Management")
                        Spacer()
                        NavigationLink("", destination: CacheManagementView())
                            .opacity(0)
                    }
                    
                    NavigationLink("Performance Settings") {
                        PerformanceSettingsView()
                    }
                }
                
                // App Information
                Section("App Information") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    // MARK: - Debug Methods
    private func resetAuthorization() {
        print("[SettingsView] Resetting authorization...")
        
        // Reset UserDefaults
        if let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") {
            groupDefaults.removeObject(forKey: "selectedRole")
            groupDefaults.removeObject(forKey: "isAuthorized")
            groupDefaults.removeObject(forKey: "authRetryCount")
            print("[SettingsView] Reset selectedRole, isAuthorized, and authRetryCount in UserDefaults")
        }
        
        // Check current authorization status
        let center = AuthorizationCenter.shared
        let currentStatus = center.authorizationStatus
        print("[SettingsView] Current authorization status: \(currentStatus)")
        
        print("[SettingsView] Please restart the app to complete the reset")
    }
    
    private func checkAuthorizationStatus() {
        let center = AuthorizationCenter.shared
        let currentStatus = center.authorizationStatus
        
        print("[SettingsView] ====== Authorization Status Check ======")
        print("[SettingsView] Authorization Status: \(currentStatus)")
        
        if let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") {
            let selectedRole = groupDefaults.string(forKey: "selectedRole")
            let isAuthorized = groupDefaults.bool(forKey: "isAuthorized")
            let isLoggedIn = groupDefaults.bool(forKey: "isLoggedIn")
            let authRetryCount = groupDefaults.integer(forKey: "authRetryCount")
            
            print("[SettingsView] UserDefaults - selectedRole: \(selectedRole ?? "nil")")
            print("[SettingsView] UserDefaults - isAuthorized: \(isAuthorized)")
            print("[SettingsView] UserDefaults - isLoggedIn: \(isLoggedIn)")
            print("[SettingsView] UserDefaults - authRetryCount: \(authRetryCount)")
        }
    }
    
    private func checkShieldStatus() {
        print("[SettingsView] ====== Shield Status Check ======")
        
        // Check ShieldManager status
        ShieldManager.shared.checkAuthorizationStatus()
        
        // Check database status
        let database = DataBase()
        let shieldedApps = database.getShieldedApplications()
        let unshieldedApps = database.getUnshieldedApplications()
        
        print("[SettingsView] Database - Shielded apps: \(shieldedApps.count)")
        print("[SettingsView] Database - Unshielded apps: \(unshieldedApps.count)")
        
        // List shielded apps
        for (id, app) in shieldedApps {
            print("[SettingsView] Shielded app: \(app.applicationName) (ID: \(id))")
        }
        
        // List unshielded apps
        for (id, app) in unshieldedApps {
            print("[SettingsView] Unshielded app: \(app.applicationName) (ID: \(id)) - Expires: \(app.expiryDate)")
        }
        
        // Check ShieldManager published properties
        let shieldManager = ShieldManager.shared
        print("[SettingsView] ShieldManager - Shielded apps: \(shieldManager.shieldedApplications.count)")
        print("[SettingsView] ShieldManager - Unshielded apps: \(shieldManager.unshieldedApplications.count)")
        
        print("[SettingsView] ====== Shield Status Check Complete ======")
    }
    
    private func forceApplyShields() {
        print("[SettingsView] ====== Force Apply Shields ======")
        
        // Force refresh data and apply shields
        ShieldManager.shared.refreshData()
        ShieldManager.shared.shieldActivities()
        
        print("[SettingsView] ====== Force Apply Shields Complete ======")
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppIconStore())
    }
}
#endif
