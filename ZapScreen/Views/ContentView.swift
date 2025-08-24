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
    @AppStorage("debugModeEnabled", store: UserDefaults(suiteName: "group.com.ntt.ZapScreen.data")) private var debugModeEnabled = false
    
    // Check if current device is a parent device
    private var isParentDevice: Bool {
        selectedRole == UserRole.parent.rawValue
    }
    
    var body: some View {

        NavigationStack {
            TabView {
                ConfigureActivitiesView()
                    .tabItem {
                        Label("Shield", systemImage: "shield")
                    }
                
                UsageStatisticsView()
                    .tabItem {
                        Label("Statistics", systemImage: "chart.bar")
                    }
                
                
                ChatView()
                    .tabItem {
                        Label("Chat", systemImage: "message")
                    }
        
                // Show Family Dashboard only for parent devices
                if isParentDevice {
                    FamilyDashboardView()
                        .tabItem {
                            Label("Family", systemImage: "person.3")
                        }
                } else {
                    // Show QR Code for child devices
                    ChildQRCodeView()
                        .tabItem {
                            Label("Pair Device", systemImage: "qrcode")
                        }
                }
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
//            .navigationTitle("ZapScreen")
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
}
