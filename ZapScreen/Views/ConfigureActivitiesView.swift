import SwiftUI

import FamilyControls

import ManagedSettings

struct ConfigureActivitiesView: View {
    @StateObject private var shieldManager = ShieldManager.shared
    @EnvironmentObject var appIconStore: AppIconStore
    private let store = ManagedSettingsStore()
    
    var body: some View {
        NavigationView {
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
                            Text("\(shieldManager.getShieldedApplications().count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Unshielded Apps")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(shieldManager.getUnshieldedApplications().count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Shielded Applications Section
                Section(header: Text("Shielded Applications")) {
                    let shieldedApps = shieldManager.getShieldedApplications()
                    if shieldedApps.isEmpty {
                        Text("No apps are currently shielded")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(Array(shieldedApps), id: \.id) { app in
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
                    let unshieldedApps = shieldManager.getUnshieldedApplications()
                    if unshieldedApps.isEmpty {
                        Text("No apps are currently unshielded")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(Array(unshieldedApps), id: \.id) { app in
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
        }
    }
}

#Preview {
    ConfigureActivitiesView()
}
