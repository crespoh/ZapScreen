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
    }

    func handleLogin() {
        // Demo: hardcoded credentials (replace with real auth logic as needed)
        if username == "admin" && password == "password" {
            isLoggedIn = true
            errorMessage = nil
            PermissionManager.requestNotificationAuthorization { granted in
                notificationGranted = granted
                updatePermissionAlert()
            }
            PermissionManager.requestLocalNetworkPermission { granted in
                localNetworkGranted = granted
                updatePermissionAlert()
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
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
