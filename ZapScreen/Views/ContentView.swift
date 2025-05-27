import SwiftUI
import FamilyControls
import Supabase

struct ContentView: View {
    @State private var showingModeSelection = false
    @State private var isLoading = true
    @State private var isConfigSheetPresented = false
    @AppStorage("isLoggedIn", store: UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")) private var isLoggedIn = false
    @AppStorage("selectedRole", store: UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")) private var selectedRole: String?
    @AppStorage("isAuthorized", store: UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")) private var isAuthorized = false
    @AppStorage("zapShowRemoteLock", store: UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")) private var zapShowRemoteLock: Bool = false
    
    var body: some View {

        NavigationStack {
            TabView {
                ConfigureActivitiesView()
                    .tabItem {
                        Label("Shield", systemImage: "shield")
                    }
                
                DeviceListView()
                    .tabItem {
                        Label("Devices", systemImage: "iphone")
                    }
                
                GroupUserDefaultsView()
                    .tabItem {
                        Label("Debug", systemImage: "ladybug")
                    }
                
                AppIconListView()
                    .tabItem {
                        Label("Icons", systemImage: "app.badge")
                    }
            }
            .navigationTitle("ZapScreen")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Logout") {
                        handleLogout()
                    }
                }
            }
            // Present RemoteLockView when showRemoteLock is true and user is parent
            .sheet(isPresented: Binding(
                get: { zapShowRemoteLock && selectedRole == UserRole.parent.rawValue },
                set: { newValue in
                    if let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") {
                        groupDefaults.set(false, forKey: "zapShowRemoteLock")
                        groupDefaults.synchronize()
                    }
                    zapShowRemoteLock = false
                }
            )) {
                RemoteUnLockView()
            }
        }
    }
    
    func handleLogout() {
        Task {
            do {
                try await SupabaseManager.shared.client.auth.signOut()
                DispatchQueue.main.async {
                    isLoggedIn = false
                    selectedRole = nil
                    isAuthorized = false
                    // Optionally clear group UserDefaults or other user state here
                    if let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") {
                        groupDefaults.removeObject(forKey: "zap_userId")
                        groupDefaults.set(false, forKey: "isLoggedIn")
                    }
                }
            } catch {
                // Optionally show an error message to the user
                print("Logout failed: \(error.localizedDescription)")
            }
        }
    }
    
}
