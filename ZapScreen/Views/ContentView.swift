import SwiftUI
import FamilyControls

struct ContentView: View {
    @State private var showingModeSelection = false
    @State private var isLoading = true
    @State private var isConfigSheetPresented = false
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("selectedRole") private var selectedRole: String?
    @AppStorage("isAuthorized") private var isAuthorized = false
    
    var body: some View {
        NavigationView {
            TabView {
            VStack {
                Button("Configure activities") {
                    isConfigSheetPresented = true
                }
                .padding()
                .sheet(isPresented: $isConfigSheetPresented) {
                    ActivityConfigSheet(isPresented: $isConfigSheetPresented)
                }
            }
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
        }
            .navigationTitle("ZapScreen")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Logout") {
                        isLoggedIn = false
                        selectedRole = nil
                        isAuthorized = false
                    }
                }
            }
        }
    }
}

