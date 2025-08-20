import SwiftUI
import Foundation
import UserNotifications
import Network
import Supabase

struct LoginView: View {
    @Environment(\.scenePhase) private var scenePhase // For app lifecycle
    // ... other properties ...
    @State private var showPermissionAlert = false
    @State private var permissionMessage = ""
    @State private var notificationGranted: Bool? = nil
    @State private var localNetworkGranted: Bool? = nil
    @AppStorage("isLoggedIn", store: UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")) private var isLoggedIn = false
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String? = nil
    @State private var isAuthorizing = false
    @State private var isRegisteringDevice = false
    @State private var registrationPollTimer: Timer? = nil

    var body: some View {

        VStack(spacing: 24) {
            Text("ZapScreen Login")
                .font(.largeTitle)
                .bold()
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .padding(.horizontal)
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: handleLogin) {
                Text("Login")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
        }
        .padding()
        .alert(isPresented: $showPermissionAlert) {
            Alert(title: Text("Permission Results"), message: Text(permissionMessage), dismissButton: .default(Text("OK")))
        }
        // Restore session on appear (once)
        .onAppear(perform: restoreSessionIfNeeded)
        // Authorizing overlay
        if isAuthorizing {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            VStack(spacing: 16) {
                ProgressView()
                Text("Authorizing...\nPlease allow notifications to continue.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .font(.headline)
            }
            .padding(40)
            .background(Color(.systemGray).opacity(0.9))
            .cornerRadius(16)
        }
        // Registering device overlay
        if isRegisteringDevice {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            VStack(spacing: 16) {
                ProgressView()
                Text("Registering device...\nWaiting for device token.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .font(.headline)
            }
            .padding(40)
            .background(Color(.systemGray).opacity(0.9))
            .cornerRadius(16)
        }
    }

    func handleLogin() {
        // ... existing code ...
        isAuthorizing = true
        errorMessage = nil
        Task {
            do {
                let session = try await SupabaseManager.shared.client.auth.signIn(email: username, password: password)
                SupabaseManager.shared.updateStoredTokens(from: session)
                // On success, request notification permission
                DispatchQueue.main.async {
                     PermissionManager.requestNotificationAuthorization { granted in
                        notificationGranted = granted
                        isAuthorizing = false
                        if granted {
                            Task {
                                isLoggedIn = true
                                errorMessage = nil
                                // Save Supabase user ID (UUID) to UserDefaults for later use
                                if let userId = SupabaseManager.shared.client.auth.currentUser?.id {
//                                    ZapScreenManager.shared.saveUserLoginInfo(userId: userId.uuidString)
                                    guard let userDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") else {
                                        print("Failed to access group UserDefaults with identifier: group.com.ntt.ZapScreen.data")
                                        return
                                    }
                                    userDefaults.set(userId.uuidString, forKey: "zap_userId")
                                    userDefaults.synchronize() // Optional, ensures immediate write
                                    print("Saved userId \(userId) to group UserDefaults (overwritten if existed)")
                                }
                                do {
                                    let session = try SupabaseManager.shared.client.auth.session
                                    SupabaseManager.shared.updateStoredTokens(from: session)
                                } catch {
                                    print("[LoginView] Failed to access Supabase session: \(error)")
                                }
                                if let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") {
                                    pollForDeviceTokenAndRegister(groupDefaults: groupDefaults)
                                    if isRegisteringDevice == false {
                                        let userIdFromDefaults = groupDefaults.string(forKey: "zap_userId") ?? "<nil>"
                                        print("[LoginView] Extracted from group UserDefaults -> userId: \(userIdFromDefaults)")
                                    }
                                    groupDefaults.set(true, forKey: "isLoggedIn")
                                } else {
                                    print("[LoginView] Failed to access group UserDefaults for verification.")
                                }
                                PermissionManager.requestLocalNetworkPermission { granted in
                                    localNetworkGranted = granted
                                    updatePermissionAlert()
                                }
                            }
                        } else {
                            errorMessage = "Notification permission is required to proceed."
                            showPermissionAlert = true
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isAuthorizing = false
                    errorMessage = "Login failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // Restore Supabase session if tokens exist in UserDefaults
    private func restoreSessionIfNeeded() {
        guard !isLoggedIn else { return }
        let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")
        guard let accessToken = groupDefaults?.string(forKey: "supabase_access_token"),
              let refreshToken = groupDefaults?.string(forKey: "supabase_refresh_token") else {
            return
        }
        Task {
            do {
                let session = try await SupabaseManager.shared.client.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
                SupabaseManager.shared.updateStoredTokens(from: session)
                if SupabaseManager.shared.client.auth.currentUser != nil {
                    DispatchQueue.main.async {
                        isLoggedIn = true
                    }
                }
            } catch {
                print("[LoginView] Failed to restore Supabase session: \(error)")
            }
        }
    }


    private func updatePermissionAlert() {
        // Only show alert if both permissions have been checked (not nil)
        if let notif = notificationGranted, let local = localNetworkGranted {
            var message = ""
            message += notif ? "Notifications: Granted\n" : "Notifications: Denied\n"
            message += local ? "Local Network: Granted" : "Local Network: Denied"
            permissionMessage = message
            showPermissionAlert = true
        }
    }
    // Poll for device token and trigger device registration
    private func pollForDeviceTokenAndRegister(groupDefaults: UserDefaults) {
        isRegisteringDevice = true
        var attempts = 0
        registrationPollTimer?.invalidate()
        registrationPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            attempts += 1
            let deviceToken = groupDefaults.string(forKey: "DeviceToken")
            if let token = deviceToken {
                print("[LoginView] Device token found after login: \(token)")
                Task {
                    do {
                        let exists = try await SupabaseManager.shared.deviceExists(deviceToken: token)
                        if exists {
                            print("[LoginView] Device already exists in Supabase.")
                        } else {
                            let deviceName = await UIDevice.current.name
                            let isParent = true // or false, depending on your logic
                            let userAccountId = SupabaseManager.shared.client.auth.currentUser?.id.uuidString ?? ""
                            let device = try await SupabaseManager.shared.addDevice(deviceToken: token, deviceName: deviceName, isParent: isParent, userAccountId: userAccountId)
                            if device != nil {
                                print("[LoginView] Device registered in Supabase.")
                            } else {
                                print("[LoginView] Failed to register device in Supabase (already exists or error).")
                            }
                        }
                    } catch {
                        print("[LoginView] Error checking/adding device in Supabase: \(error)")
                    }
                    await MainActor.run {
                        isRegisteringDevice = false
                        timer.invalidate()
                        registrationPollTimer = nil
                    }
                }
            } else if attempts >= 30 {
                print("[LoginView] Device token not found after 30s, giving up.")
                Task {
                    await MainActor.run {
                        isRegisteringDevice = false
                        timer.invalidate()
                        registrationPollTimer = nil
                    }
                }
            } else {
                print("[LoginView] Waiting for device token... (attempt \(attempts))")
            }
        }
    }

}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
