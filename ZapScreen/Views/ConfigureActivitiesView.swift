import SwiftUI
import FamilyControls
import ManagedSettings

struct ConfigureActivitiesView: View {
    @StateObject private var shieldManager = ShieldManager.shared
    @StateObject private var passcodeManager = PasscodeManager.shared
    @EnvironmentObject var appIconStore: AppIconStore
    @State private var showingAddActivity = false
    @State private var isViewActive = false
    private let store = ManagedSettingsStore()
    
    var body: some View {
        NavigationView {
            Group {
                if passcodeManager.isPasscodeEnabled && passcodeManager.isLocked && !isViewActive {
                    // Show passcode prompt if device is locked AND view is not active
                    VStack {
                        PasscodePromptView()
                    }
//                    .navigationTitle("Configure Activities")
                    .navigationBarTitleDisplayMode(.inline)
                } else {
                    // Show simplified configure activities UI
                    VStack(spacing: 0) {
                        // Add Activity Button
                        VStack(spacing: 16) {
                            AddActivityButton {
                                showingAddActivity = true
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top)
                        
                        // App List
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                // Shielded Applications
                                if !shieldManager.shieldedApplications.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Restricted Apps")
                                            .font(.headline)
                                            .padding(.horizontal)
                                        
                                        LazyVStack(spacing: 8) {
                                            ForEach(Array(shieldManager.shieldedApplications), id: \.id) { app in
                                                AppStatusCard(
                                                    appName: app.applicationName,
                                                    isShielded: true,
                                                    onRemove: {
                                                        shieldManager.removeApplicationFromShield(app)
                                                    },
                                                    showDeleteButton: true  // Show delete for restricted apps
                                                )
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                
                                // Temporarily Unshielded Applications
                                if !shieldManager.unshieldedApplications.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Temporarily Unlocked")
                                            .font(.headline)
                                            .padding(.horizontal)
                                        
                                        LazyVStack(spacing: 8) {
                                            ForEach(Array(shieldManager.unshieldedApplications), id: \.id) { app in
                                                HStack {
                                                    AppStatusCard(
                                                        appName: app.applicationName,
                                                        isShielded: false,
                                                        onRemove: {
                                                            if app.isExpired {
                                                                shieldManager.reapplyShieldToExpiredApp(app)
                                                            }
                                                        },
                                                        showDeleteButton: false  // Hide delete for temporarily unlocked apps
                                                    )
                                                    
                                                    // Show remaining time or expired status
                                                    VStack(alignment: .trailing, spacing: 4) {
                                                        if !app.isExpired {
                                                            Text("\(app.durationMinutes) min")
                                                                .font(.caption)
                                                                .foregroundColor(.blue)
                                                            
                                                            Text("\(app.formattedRemainingTime) left")
                                                                .font(.caption2)
                                                                .foregroundColor(.orange)
                                                        } else {
                                                            Text("Expired")
                                                                .font(.caption)
                                                                .foregroundColor(.red)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                
                                // Empty State
                                if shieldManager.shieldedApplications.isEmpty && shieldManager.unshieldedApplications.isEmpty {
                                    EmptyStateView(
                                        title: "No Apps Configured",
                                        message: "Add your first app to start managing screen time",
                                        iconName: "app.badge.plus"
                                    )
                                    .padding(.top, 40)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
//                    .navigationTitle("Configure Activities")
                    .navigationBarTitleDisplayMode(.inline)
                    .sheet(isPresented: $showingAddActivity) {
                        ShieldCustomView()
                    }
                    .onAppear {
                        // Mark view as active to prevent passcode prompt
                        isViewActive = true
                        
                        // Refresh data when view appears
                        shieldManager.refreshData()
                        
                        // Debug: Print current passcode state
                        print("[ConfigureActivitiesView] Passcode enabled: \(passcodeManager.isPasscodeEnabled)")
                        print("[ConfigureActivitiesView] Device locked: \(passcodeManager.isLocked)")
                        print("[ConfigureActivitiesView] View active: \(isViewActive)")
                        
                        // Debug: Print current shield status
                        print("[ConfigureActivitiesView] ====== Current UI State ======")
                        print("[ConfigureActivitiesView] Shielded Apps Count: \(shieldManager.shieldedApplications.count)")
                        for app in shieldManager.shieldedApplications {
                            print("[ConfigureActivitiesView] Shielded App: \(app.applicationName)")
                        }
                        print("[ConfigureActivitiesView] Unshielded Apps Count: \(shieldManager.unshieldedApplications.count)")
                        for app in shieldManager.unshieldedApplications {
                            print("[ConfigureActivitiesView] Unshielded App: \(app.applicationName) - Expired: \(app.isExpired)")
                        }
                        print("[ConfigureActivitiesView] ====== UI State Complete ======")
                    }
                    .onDisappear {
                        // Mark view as inactive when leaving
                        isViewActive = false
                        print("[ConfigureActivitiesView] View inactive: \(isViewActive)")
                    }
                }
            }
        }
    }
}

#Preview {
    ConfigureActivitiesView()
}
