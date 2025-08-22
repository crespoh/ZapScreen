import SwiftUI

import FamilyControls

import ManagedSettings

struct ConfigureActivitiesView: View {
    @StateObject private var shieldManager = ShieldManager.shared
    @StateObject private var passcodeManager = PasscodeManager.shared
    @EnvironmentObject var appIconStore: AppIconStore
    private let store = ManagedSettingsStore()
    
    var body: some View {
        NavigationView {
            Group {
                if passcodeManager.isPasscodeEnabled && passcodeManager.isLocked {
                    // Show passcode prompt if device is locked
                    VStack {
                        PasscodePromptView()
                    }
                    .navigationTitle("Shield")
                    .navigationBarTitleDisplayMode(.inline)
                } else {
                    // Show normal configure activities UI
            List {
                // Navigation Links Section
                Section {
                    NavigationLink(destination: ShieldCustomView()) {
                        Text("Add Activity")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    NavigationLink(destination: AppStatusView()) {
                        Text("View App Status")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                
                // Status Section
                Section(header: Text("Current Shield Status")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Shielded Apps")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(shieldManager.shieldedApplications.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Unshielded Apps")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(shieldManager.unshieldedApplications.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Shielded Applications Section
                Section(header: Text("Shielded Applications")) {
                    if shieldManager.shieldedApplications.isEmpty {
                        Text("No apps are currently shielded")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(Array(shieldManager.shieldedApplications), id: \.id) { app in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(app.applicationName)
                                        .font(.body)
                                    Text("Permanently blocked")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Remove") {
                                    shieldManager.removeApplicationFromShield(app)
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                                .controlSize(.small)
                            }
                        }
                    }
                }
                
                // Unshielded Applications Section
                Section(header: Text("Temporarily Unshielded")) {
                    if shieldManager.unshieldedApplications.isEmpty {
                        Text("No apps are currently unshielded")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(Array(shieldManager.unshieldedApplications), id: \.id) { app in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(app.applicationName)
                                        .font(.body)
                                    Text("Unlocked for \(app.durationMinutes) minutes")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if !app.isExpired {
                                        Text("Time remaining: \(app.formattedRemainingTime)")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    } else {
                                        Text("Expired - will be re-shielded")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    }
                                }
                                Spacer()
                                if app.isExpired {
                                    Button("Re-shield") {
                                        shieldManager.reapplyShieldToExpiredApp(app)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Shield")
            .onAppear {
                // Refresh data when view appears
                shieldManager.refreshData()
                
                // Debug: Print current passcode state
                print("[ConfigureActivitiesView] Passcode enabled: \(passcodeManager.isPasscodeEnabled)")
                print("[ConfigureActivitiesView] Device locked: \(passcodeManager.isLocked)")
            }
        }
        }
        }
    }
}

#Preview {
    ConfigureActivitiesView()
}
