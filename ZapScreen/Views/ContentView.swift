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
                // Clear UI state
                isLoggedIn = false
                selectedRole = nil
                isAuthorized = false
                // Clear all relevant group UserDefaults
                if let groupDefaults = UserDefaults(suiteName: "group.com.ntt.ZapScreen.data") {
                    groupDefaults.removeObject(forKey: "supabase_access_token")
                    groupDefaults.removeObject(forKey: "supabase_refresh_token")
                    groupDefaults.removeObject(forKey: "zap_userId")
                    groupDefaults.removeObject(forKey: "zap_userRole")
                    groupDefaults.set(false, forKey: "isLoggedIn")
                }
                // Supabase sign out
                try await SupabaseManager.shared.client.auth.signOut()
            } catch {
                print("Logout failed: \(error.localizedDescription)")
            }
        }
    }

}
