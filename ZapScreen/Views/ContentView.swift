import SwiftUI
import FamilyControls

struct ContentView: View {
    @State private var showingModeSelection = false
    @State private var isLoading = true
    
    var body: some View {
        TabView {
            ShieldView()
                .tabItem {
                    Label("Shield", systemImage: "shield")
                }
            
            DeviceListView()
                .tabItem {
                    Label("Devices", systemImage: "iphone")
                }
            
            UserDefaultsView()
                .tabItem {
                    Label("Debug", systemImage: "ladybug")
                }
        }
    }
}

