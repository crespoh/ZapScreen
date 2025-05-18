import SwiftUI
import FamilyControls

struct RootView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("selectedRole") private var selectedRoleRaw: String?
    @AppStorage("isAuthorized") private var isAuthorized = false
    let center = AuthorizationCenter.shared

    var selectedRole: UserRole? {
        get { selectedRoleRaw.flatMap { UserRole(rawValue: $0) } }
        set { selectedRoleRaw = newValue?.rawValue }
    }

    var body: some View {
        if !isLoggedIn {
            LoginView()
        } else if selectedRole == nil {
            SelectionView { role in
                let raw = role.rawValue
                Task { @MainActor in
                    selectedRoleRaw = raw
                    do {
                        if role == .child {
                            try await center.requestAuthorization(for: .child)
                        } else {
                            try await center.requestAuthorization(for: .individual)
                        }
                        isAuthorized = true
                    } catch {
                        print("Failed to get authorization: \(error)")
                        isAuthorized = false
                        selectedRoleRaw = nil
                    }
                }
            }
        } else if !isAuthorized {
            VStack {
                ProgressView()
                Text("Authorizing...")
            }
        } else {
            ContentView()
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
        .environmentObject(AppIconStore())
    }
}
