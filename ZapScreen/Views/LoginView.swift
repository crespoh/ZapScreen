import SwiftUI
import Foundation
import UserNotifications
import Network

struct LoginView: View {
    @State private var showPermissionAlert = false
    @State private var permissionMessage = ""
    @State private var notificationGranted: Bool? = nil
    @State private var localNetworkGranted: Bool? = nil
    @AppStorage("isLoggedIn") private var isLoggedIn = false
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
        // Demo: hardcoded credentials (replace with real auth logic as needed)
        if username == "admin" && password == "password" {
            // Show authorizing overlay while waiting for notification permission
            isAuthorizing = true
            PermissionManager.requestNotificationAuthorization { granted in
//                DispatchQueue.main.async {
                    notificationGranted = granted
                    isAuthorizing = false
                    if granted {
                        // Continue login flow
                        isLoggedIn = true
                        errorMessage = nil
                        // Save userId to group UserDefaults
                        ZapScreenManager.shared.saveUserLoginInfo(userId: username)
                        // Log extraction from group UserDefaults
                        if let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") {
                            // Start polling for deviceToken
                            pollForDeviceTokenAndRegister(groupDefaults: groupDefaults)
                            if isRegisteringDevice == false {
                                let userIdFromDefaults = groupDefaults.string(forKey: "zap_userId") ?? "<nil>"
                                print("[LoginView] Extracted from group UserDefaults -> userId: \(userIdFromDefaults)")
                            }
                            // Set isLoggedIn to true for device registration coordination
                            groupDefaults.set(true, forKey: "isLoggedIn")

                        } else {
                            print("[LoginView] Failed to access group UserDefaults for verification.")
                        }
                        PermissionManager.requestLocalNetworkPermission { granted in
                            localNetworkGranted = granted
                            updatePermissionAlert()
                        }
                    } else {
                        // Show authorizing/permission alert (can customize as needed)
                        errorMessage = "Notification permission is required to proceed."
                        showPermissionAlert = true
                    }
//                }
            }
        } else {
            errorMessage = "Invalid username or password."
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
                ZapScreenManager.shared.handleDeviceRegistration(deviceToken: token) { success in
                    print("[LoginView] Device registration after login (polled): \(success) ")
                }
                isRegisteringDevice = false
                timer.invalidate()
                registrationPollTimer = nil
            } else if attempts >= 30 {
                print("[LoginView] Device token not found after 30s, giving up.")
                isRegisteringDevice = false
                timer.invalidate()
                registrationPollTimer = nil
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
