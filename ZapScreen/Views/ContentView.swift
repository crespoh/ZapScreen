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
        NavigationStack {
            TabView {
            VStack {
                NavigationLink(destination: ShieldCustomView()) {
                    Text("Configure Activities")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
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

