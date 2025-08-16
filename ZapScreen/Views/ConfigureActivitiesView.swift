import SwiftUI

import FamilyControls

import ManagedSettings

struct ConfigureActivitiesView: View {
    @StateObject private var shieldManager = ShieldManager.shared
    @EnvironmentObject var appIconStore: AppIconStore
    private let store = ManagedSettingsStore()
    private let db = DataBase()
    @StateObject var model = AppSelectionModel.shared
    @State private var showingAddActivity = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Change from NavigationLink to Button
                Button("Add Activity") {
                    showingAddActivity = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding()
                
                // Display current locked apps with delete functionality
                VStack(alignment: .leading, spacing: 8) {
                    Text("Locked Apps")
                        .font(.headline)
                    
                    if shieldManager.discouragedSelections.applicationTokens.isEmpty {
                        Text("No apps are currently locked.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(shieldManager.discouragedSelections.applicationTokens), id: \.self) { token in
                            LockedAppRow(
                                token: token,
                                onDelete: {
                                    removeAppFromShield(token)
                                }
                            )
                        }
                    }
                }
                .padding(.top)
                
                Spacer()
            }
            .navigationTitle("Shield")
            .sheet(isPresented: $showingAddActivity) {
                AddActivityView()
            }
            .onAppear {
                print("[ConfigureActivitiesView] View appeared - starting sync...")
                // Sync ShieldManager with existing data from database
                syncShieldManagerWithDatabase()
            }
        }
    }
    
    private func removeAppFromShield(_ token: ApplicationToken) {
        print("[ConfigureActivitiesView] Removing app from shield: \(token)")
        print("[ConfigureActivitiesView] Before removal - Total apps in ShieldManager: \(shieldManager.discouragedSelections.applicationTokens.count)")
        
        // Use ShieldManager to remove the app completely
        shieldManager.removeApplicationCompletely(token)
        
        print("[ConfigureActivitiesView] After removal - Total apps in ShieldManager: \(shieldManager.discouragedSelections.applicationTokens.count)")
        
        // Sync with AppSelectionModel
        model.syncWithShieldManager(shieldManager)
        
        print("[ConfigureActivitiesView] App completely removed from shield system")
    }
    
    private func syncShieldManagerWithDatabase() {
        print("[ConfigureActivitiesView] Starting sync with database...")
        
        // Load existing application profiles from database
        let profiles = db.getApplicationProfiles()
        print("[ConfigureActivitiesView] Found \(profiles.count) profiles in database")
        
        // Clear current ShieldManager selections
        shieldManager.discouragedSelections.applicationTokens.removeAll()
        
        // Add each profile's token to ShieldManager
        for profile in profiles.values {
            shieldManager.discouragedSelections.applicationTokens.insert(profile.applicationToken)
            print("[ConfigureActivitiesView] Added profile: \(profile.applicationName)")
        }
        
        // Apply the shield settings
        shieldManager.shieldActivities()
        
        // Sync with AppSelectionModel
        model.syncWithShieldManager(shieldManager)
        
        print("[ConfigureActivitiesView] Sync completed. Total apps in ShieldManager: \(shieldManager.discouragedSelections.applicationTokens.count)")
    }
}

// New component for displaying locked apps with delete button
struct LockedAppRow: View {
    let token: ApplicationToken
    let onDelete: () -> Void
    @State private var appName: String = "Unknown App"
    
    var body: some View {
        HStack {
            Label(appName, systemImage: "app.badge")
                .labelStyle(.titleAndIcon)
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            loadAppName()
        }
    }
    
    private func loadAppName() {
        let db = DataBase()
        let profiles = db.getApplicationProfiles()
        for profile in profiles.values {
            if profile.applicationToken == token {
                appName = profile.applicationName
                print("[LockedAppRow] Loaded app name: \(appName)")
                break
            }
        }
    }
}

#Preview {
    ConfigureActivitiesView()
}
