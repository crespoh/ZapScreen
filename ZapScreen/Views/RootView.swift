import SwiftUI
import FamilyControls

struct RootView: View {
    @AppStorage("isLoggedIn", store: UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")) private var isLoggedIn = false
    @AppStorage("selectedRole", store: UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")) private var selectedRoleRaw: String?
    @AppStorage("isAuthorized", store: UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")) private var isAuthorized = false
    @AppStorage("authRetryCount", store: UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")) private var authRetryCount = 0
    let center = AuthorizationCenter.shared
    
    // Helper function to handle authorization errors gracefully
    private func handleAuthorizationError(_ error: Error) {
        print("[RootView] Handling authorization error: \(error)")
        
        if let authError = error as? FamilyControlsError {
            switch authError {
            case .authorizationConflict:
                print("[RootView] 🔄 Authorization conflict detected - this should be rare now with smart checking")
                // Since we're now checking status first, conflicts should be rare
                // Just proceed anyway since we know the user has authorization
                isAuthorized = true
                ShieldManager.shared.shieldActivities()
                
            case .authorizationCanceled:
                print("[RootView] ❌ Authorization canceled by user")
                isAuthorized = false
                selectedRoleRaw = nil
                
            default:
                print("[RootView] ⚠️ Other authorization error: \(authError)")
                // For other errors, try to proceed anyway
                isAuthorized = true
            }
        } else {
            print("[RootView] ❓ Unknown authorization error: \(error)")
            // For unknown errors, try to proceed anyway
            isAuthorized = true
        }
    }

    var selectedRole: UserRole? {
        get { selectedRoleRaw.flatMap { UserRole(rawValue: $0) } }
        set { selectedRoleRaw = newValue?.rawValue }
    }

    var body: some View {
        Group {
            if !isLoggedIn {
                LoginView()
            } else if selectedRole == nil {
                SelectionView { role in
                    let raw = role.rawValue
                                                    Task { @MainActor in
                    selectedRoleRaw = raw
                    authRetryCount = 0 // Reset retry count for new role selection
                    
                    // SMART AUTHORIZATION CHECK - Check status BEFORE requesting
                    let currentStatus = center.authorizationStatus
                    print("[RootView] Smart Authorization Check - Current status: \(currentStatus)")
                    
                    // Only request authorization if not already approved
                    if currentStatus == .approved {
                        // Already authorized - proceed immediately without requesting
                        print("[RootView] ✅ Already authorized, proceeding directly")
                        isAuthorized = true
                        ShieldManager.shared.shieldActivities()
                    } else if currentStatus == .notDetermined {
                        // Not determined - safe to request authorization
                        print("[RootView] 🔄 Authorization not determined, requesting for role: \(role)")
                        
                        do {
                            if role == .child {
                                try await center.requestAuthorization(for: .child)
                            } else {
                                try await center.requestAuthorization(for: .individual)
                            }
                            isAuthorized = true
                            print("[RootView] ✅ Authorization successful")
                            ShieldManager.shared.shieldActivities()
                        } catch {
                            print("[RootView] ❌ Authorization request failed: \(error)")
                            handleAuthorizationError(error)
                        }
                    } else if currentStatus == .denied {
                        // Authorization denied - show guidance but proceed
                        print("[RootView] ⚠️ Authorization denied, proceeding anyway")
                        isAuthorized = true
                        // Could show a message to user about enabling Family Controls in Settings
                    } else {
                        // Other statuses - proceed anyway
                        print("[RootView] ℹ️ Authorization status: \(currentStatus), proceeding anyway")
                        isAuthorized = true
                    }
                }
                }
                    } else if !isAuthorized {
            VStack(spacing: 20) {
                ProgressView()
                Text("Authorizing...")
                
                // Emergency button (should rarely be needed now)
                Button("Force Continue (Emergency)") {
                    print("[RootView] Emergency force continue pressed")
                    isAuthorized = true
                    authRetryCount = 0
                    ShieldManager.shared.shieldActivities()
                }
                .buttonStyle(.borderedProminent)
                .foregroundColor(.orange)
                .font(.caption)
            }
            .onAppear {
                // Check if we need to request authorization when this view appears
                let currentStatus = center.authorizationStatus
                print("[RootView] Authorizing View - Authorization Check - Status: \(currentStatus), Role: \(selectedRole?.rawValue ?? "nil")")
                
                if currentStatus == .notDetermined && selectedRole != nil {
                    print("[RootView] Authorizing View - 🔄 Requesting authorization for role: \(selectedRole?.rawValue ?? "unknown")")
                    // Request authorization immediately
                    Task { @MainActor in
                        do {
                            if selectedRole == .child {
                                print("[RootView] Authorizing View - Requesting child authorization...")
                                try await center.requestAuthorization(for: .child)
                            } else {
                                print("[RootView] Authorizing View - Requesting individual authorization...")
                                try await center.requestAuthorization(for: .individual)
                            }
                            isAuthorized = true
                            print("[RootView] Authorizing View - ✅ Authorization successful")
                            ShieldManager.shared.shieldActivities()
                        } catch {
                            print("[RootView] Authorizing View - ❌ Authorization request failed: \(error)")
                            handleAuthorizationError(error)
                        }
                    }
                }
            }
            } else {
                ContentView()
            }
        }
        .onAppear {
            // Smart authorization check when the view appears
            let currentStatus = center.authorizationStatus
            print("[RootView] OnAppear - Smart Authorization Check - Status: \(currentStatus)")
            print("[RootView] OnAppear - Debug: selectedRole=\(selectedRole?.rawValue ?? "nil"), isAuthorized=\(isAuthorized)")
            
            if selectedRole != nil {
                if currentStatus == .approved && !isAuthorized {
                    print("[RootView] OnAppear - ✅ Already authorized, updating status")
                    isAuthorized = true
                    ShieldManager.shared.shieldActivities()
                } else if currentStatus == .notDetermined && !isAuthorized {
                    print("[RootView] OnAppear - 🔄 Authorization not determined, requesting authorization for role: \(selectedRole?.rawValue ?? "unknown")")
                    // Request authorization for the selected role
                    Task { @MainActor in
                        do {
                            if selectedRole == .child {
                                print("[RootView] OnAppear - Requesting child authorization...")
                                try await center.requestAuthorization(for: .child)
                            } else {
                                print("[RootView] OnAppear - Requesting individual authorization...")
                                try await center.requestAuthorization(for: .individual)
                            }
                            isAuthorized = true
                            print("[RootView] OnAppear - ✅ Authorization successful")
                            ShieldManager.shared.shieldActivities()
                        } catch {
                            print("[RootView] OnAppear - ❌ Authorization request failed: \(error)")
                            handleAuthorizationError(error)
                        }
                    }
                } else if currentStatus == .notDetermined && isAuthorized {
                    print("[RootView] OnAppear - ⚠️ Status is Not Determined but isAuthorized is true - this shouldn't happen")
                    // This case shouldn't happen, but let's handle it
                    isAuthorized = false
                } else if currentStatus != .approved && isAuthorized {
                    print("[RootView] OnAppear - ⚠️ Authorization status changed to not approved")
                    isAuthorized = false
                } else {
                    print("[RootView] OnAppear - ℹ️ No action needed - Status: \(currentStatus), isAuthorized: \(isAuthorized)")
                }
            } else {
                print("[RootView] OnAppear - No role selected yet")
            }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
        .environmentObject(AppIconStore())
    }
}
