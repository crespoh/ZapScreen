//
//  SettingsView.swift
//  ZapScreen
//
//  Created by tongteknai on 18/5/25.
//

import SwiftUI
import ManagedSettings
import ManagedSettingsUI

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
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppIconStore())
    }
}
#endif
