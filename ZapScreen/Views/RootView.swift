import SwiftUI
import FamilyControls

struct RootView: View {
    @AppStorage("isLoggedIn", store: UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")) private var isLoggedIn = false
    @AppStorage("selectedRole", store: UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")) private var selectedRoleRaw: String?
    @AppStorage("isAuthorized", store: UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")) private var isAuthorized = false
    @AppStorage("authRetryCount", store: UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")) private var authRetryCount = 0
    let center = AuthorizationCenter.shared

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
                    
                    // Check current authorization status first
                    let currentStatus = center.authorizationStatus
                    print("[RootView] Current authorization status: \(currentStatus)")
                    
                    do {
                                                    if currentStatus == .approved {
                            // Already authorized, no need to request again
                            print("[RootView] Already authorized, skipping request")
                            isAuthorized = true
                            // Reapply shields since authorization is now confirmed
                            ShieldManager.shared.shieldActivities()
                        } else if currentStatus == .notDetermined {
                            print("[RootView] Authorization not determined, requesting for role: \(role)")
                            // Add a small delay to avoid conflicts
                            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            
                            if role == .child {
                                try await center.requestAuthorization(for: .child)
                            } else {
                                try await center.requestAuthorization(for: .individual)
                            }
                            isAuthorized = true
                            print("[RootView] Authorization successful")
                            // Reapply shields after successful authorization
                            ShieldManager.shared.shieldActivities()
                        } else {
                            print("[RootView] Authorization status: \(currentStatus), proceeding anyway")
                            // For other statuses (denied, restricted), proceed anyway
                            isAuthorized = true
                        }
                        } catch {
                            print("[RootView] Failed to get authorization: \(error)")
                            
                            // Handle specific error cases
                            if let authError = error as? FamilyControlsError {
                                switch authError {
                                                            case .authorizationConflict:
                                print("[RootView] Authorization conflict - checking current status")
                                authRetryCount += 1
                                print("[RootView] Authorization conflict detected - status: \(center.authorizationStatus), retry count: \(authRetryCount)")
                                
                                // If we've tried too many times, just proceed anyway
                                if authRetryCount >= 3 {
                                    print("[RootView] Too many retries, proceeding anyway")
                                    isAuthorized = true
                                    authRetryCount = 0
                                } else {
                                    // Check if we have a stored role and try to proceed anyway
                                    if let storedRole = selectedRoleRaw {
                                        print("[RootView] Keeping stored role: \(storedRole)")
                                        // Don't reset the role, just mark as authorized to break the loop
                                        isAuthorized = true
                                                                           print("[RootView] Proceeding with stored role despite conflict")
                                   // Reapply shields when proceeding despite conflict
                                   ShieldManager.shared.shieldActivities()
                                   } else {
                                        print("[RootView] No stored role, resetting")
                                        isAuthorized = false
                                        selectedRoleRaw = nil
                                    }
                                }
                                case .authorizationCanceled:
                                    print("[RootView] Authorization canceled by user")
                                    isAuthorized = false
                                    selectedRoleRaw = nil
                                default:
                                    print("[RootView] Other authorization error: \(authError)")
                                    isAuthorized = false
                                    selectedRoleRaw = nil
                                }
                            } else {
                                print("[RootView] Unknown authorization error")
                                isAuthorized = false
                                selectedRoleRaw = nil
                            }
                        }
                    }
                }
                    } else if !isAuthorized {
            VStack(spacing: 20) {
                ProgressView()
                Text("Authorizing...")
                
                // Emergency break-the-loop button
                                       Button("Force Continue (Emergency)") {
                           print("[RootView] Emergency force continue pressed")
                           isAuthorized = true
                           authRetryCount = 0
                           // Reapply shields when force continuing
                           ShieldManager.shared.shieldActivities()
                       }
                .buttonStyle(.borderedProminent)
                .foregroundColor(.red)
            }
            } else {
                ContentView()
            }
        }
        .onAppear {
            // Check authorization status when the view appears
            let currentStatus = center.authorizationStatus
            print("[RootView] OnAppear - Authorization status: \(currentStatus)")
            
            if selectedRole != nil && currentStatus == .approved && !isAuthorized {
                print("[RootView] OnAppear - Updating authorization status to true")
                isAuthorized = true
            } else if selectedRole != nil && currentStatus != .approved && isAuthorized {
                print("[RootView] OnAppear - Authorization status changed to not approved")
                isAuthorized = false
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
